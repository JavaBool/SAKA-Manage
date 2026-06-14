import csv
import io
from datetime import datetime
from flask import Blueprint, request, jsonify, Response, send_file
from backend.models.database import db
from backend.models.models import Report, Contact, Product, Attachment, User
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action
from backend.services.storage_service import get_storage_service
from backend.services.notification_service import notify_all_bosses

reports_bp = Blueprint('reports', __name__)

@reports_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_reports():
    reports = Report.query.order_by(Report.created_at.desc()).all()
    return jsonify([r.to_dict() for r in reports]), 200

@reports_bp.route('/<uuid:report_id>', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_report(report_id):
    report = Report.query.get_or_404(report_id)
    res = report.to_dict()
    res['followups'] = [f.to_dict() for f in report.followups]
    res['attachments'] = [a.to_dict() for a in report.attachments]
    return jsonify(res), 200

@reports_bp.route('', methods=['POST'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def create_report():
    import uuid
    role, user_id = get_current_user_role_and_id()
    
    # Form data parsing
    contact_id = request.form.get('contact_id')
    product_id = request.form.get('product_id')
    feedback_type = request.form.get('feedback_type')
    summary = request.form.get('summary')
    details = request.form.get('details')
    priority = request.form.get('priority')
    status = request.form.get('status', 'open')
    next_followup_str = request.form.get('next_followup_date')
    
    # Validation
    if not all([contact_id, product_id, feedback_type, summary, details, priority]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        db_contact_id = uuid.UUID(str(contact_id))
        db_product_id = uuid.UUID(str(product_id))
    except ValueError:
        return jsonify({"error": "Invalid contact_id or product_id format"}), 400

    # Check valid values
    if feedback_type not in ('positive', 'negative', 'complaint', 'suggestion', 'feature_request'):
        return jsonify({"error": "Invalid feedback_type"}), 400
        
    if priority not in ('low', 'medium', 'high', 'critical'):
        return jsonify({"error": "Invalid priority"}), 400
        
    if status not in ('open', 'followup_pending', 'closed'):
        return jsonify({"error": "Invalid status"}), 400
        
    # Check contact
    contact = Contact.query.get(db_contact_id)
    if not contact:
        return jsonify({"error": "Contact not found"}), 404
    if role == 'MANAGER' and contact.assigned_manager_id != user_id:
        return jsonify({"error": "Contact is not assigned to you"}), 403
        
    # Check product exists
    product = Product.query.get(db_product_id)
    if not product or not product.active:
        return jsonify({"error": "Active product not found"}), 404
        
    # Parse date
    next_followup_date = None
    if next_followup_str:
        try:
            next_followup_date = datetime.fromisoformat(next_followup_str.replace('Z', '+00:00'))
        except ValueError:
            return jsonify({"error": "Invalid next_followup_date format (expecting ISO 8601)"}), 400
            
    report = Report(
        contact_id=db_contact_id,
        manager_id=user_id,
        product_id=db_product_id,
        feedback_type=feedback_type,
        summary=summary,
        details=details,
        priority=priority,
        status=status,
        next_followup_date=next_followup_date
    )
    db.session.add(report)
    db.session.flush()  # get report.id
    
    # Save attachments
    storage = get_storage_service()
    uploaded_files = request.files.getlist('attachments')
    for file in uploaded_files:
        if file and file.filename:
            # Save file data to storage service
            # Calculate file size
            file.seek(0, 2)
            size = file.tell()
            file.seek(0)
            
            filepath = storage.save_file(file, file.filename, file.mimetype)
            
            attachment = Attachment(
                report_id=report.id,
                filename=file.filename,
                filepath=filepath,
                mime_type=file.mimetype or 'application/octet-stream',
                size=size
            )
            db.session.add(attachment)
            
    db.session.commit()
    
    # Audit log
    log_action(
        action="Report Creation",
        user_id=user_id,
        entity_type="reports",
        entity_id=report.id,
        new_value=report.to_dict(),
        ip_address=request.remote_addr
    )
    
    # Push Notifications to Bosses
    manager_user = User.query.get(user_id)
    mgr_name = manager_user.username if manager_user else "Manager"
    cust_company = contact.company or contact.name
    
    notif_title = f"New Report Submitted (Priority: {priority.upper()})"
    if priority == 'critical':
        notif_title = "🚨 CRITICAL Report Submitted!"
        
    notif_msg = f"Customer: {cust_company}\nManager: {mgr_name}\nSummary: {summary}"
    
    notify_all_bosses(
        title=notif_title,
        message=notif_msg,
        entity_type="report",
        entity_id=report.id
    )
    
    return jsonify(report.to_dict()), 201

@reports_bp.route('/<uuid:report_id>', methods=['PUT'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def update_report(report_id):
    role, user_id = get_current_user_role_and_id()
    report = Report.query.get_or_404(report_id)
    
    # Editing must be done only by the report creator
    if str(report.manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Editing is only allowed for the report creator"}), 403
        
    data = request.get_json() or {}
    old_value = report.to_dict()
    old_priority = report.priority
    
    # Update fields
    if 'feedback_type' in data:
        ft = data['feedback_type']
        if ft not in ('positive', 'negative', 'complaint', 'suggestion', 'feature_request'):
            return jsonify({"error": "Invalid feedback_type"}), 400
        report.feedback_type = ft
        
    if 'summary' in data:
        report.summary = data['summary']
        
    if 'details' in data:
        report.details = data['details']
        
    if 'priority' in data:
        pr = data['priority']
        if pr not in ('low', 'medium', 'high', 'critical'):
            return jsonify({"error": "Invalid priority"}), 400
        report.priority = pr
        
    if 'status' in data:
        st = data['status']
        if st not in ('open', 'followup_pending', 'closed'):
            return jsonify({"error": "Invalid status"}), 400
        report.status = st
        
    if 'next_followup_date' in data:
        nf_str = data['next_followup_date']
        if nf_str:
            try:
                report.next_followup_date = datetime.fromisoformat(nf_str.replace('Z', '+00:00'))
            except ValueError:
                return jsonify({"error": "Invalid next_followup_date format (expecting ISO 8601)"}), 400
        else:
            report.next_followup_date = None
            
    db.session.commit()
    
    # Audit log
    log_action(
        action="Report Update",
        user_id=user_id,
        entity_type="reports",
        entity_id=report.id,
        old_value=old_value,
        new_value=report.to_dict(),
        ip_address=request.remote_addr
    )
    
    # Push Notifications on update
    manager_user = User.query.get(user_id)
    mgr_name = manager_user.username if manager_user else "Manager"
    contact = Contact.query.get(report.contact_id)
    cust_company = contact.company or contact.name if contact else "Unknown"
    
    # If priority became critical
    is_critical_trigger = (report.priority == 'critical' and old_priority != 'critical')
    
    notif_title = f"Report Updated (Status: {report.status.upper()})"
    if is_critical_trigger:
        notif_title = "🚨 Report Escalated to CRITICAL!"
    elif report.priority == 'critical':
        notif_title = "🚨 CRITICAL Report Updated"
        
    notif_msg = f"Customer: {cust_company}\nManager: {mgr_name}\nSummary: {report.summary}"
    
    notify_all_bosses(
        title=notif_title,
        message=notif_msg,
        entity_type="report",
        entity_id=report.id
    )
    
    return jsonify(report.to_dict()), 200

@reports_bp.route('/export', methods=['GET'])
@role_required('ADMIN', 'BOSS')
def export_reports():
    """
    Export all reports in CSV format.
    """
    role, user_id = get_current_user_role_and_id()
    reports = Report.query.order_by(Report.created_at.desc()).all()
    
    # Generate CSV in memory
    si = io.StringIO()
    cw = csv.writer(si)
    
    # Headers
    cw.writerow([
        'Report ID', 'Contact Name', 'Contact Company', 'Product Name', 
        'Manager Username', 'Feedback Type', 'Summary', 'Details', 
        'Priority', 'Status', 'Next Followup Date', 'Created At', 'Updated At'
    ])
    
    for r in reports:
        cw.writerow([
            str(r.id),
            r.contact.name if r.contact else '',
            r.contact.company if r.contact else '',
            r.product.name if r.product else '',
            r.manager.username if r.manager else '',
            r.feedback_type,
            r.summary,
            r.details,
            r.priority,
            r.status,
            r.next_followup_date.isoformat() if r.next_followup_date else '',
            r.created_at.isoformat() if r.created_at else '',
            r.updated_at.isoformat() if r.updated_at else ''
        ])
        
    output = make_response_csv(si.getvalue())
    return output

def make_response_csv(csv_data):
    response = Response(csv_data, mimetype='text/csv')
    response.headers["Content-Disposition"] = "attachment; filename=reports_export.csv"
    return response
