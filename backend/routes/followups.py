from flask import Blueprint, request, jsonify
from backend.models.database import db
from backend.models.models import Followup, Report
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action

followups_bp = Blueprint('followups', __name__)

@followups_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_followups():
    import uuid
    role, user_id = get_current_user_role_and_id()
    report_id = request.args.get('report_id')
    
    if not report_id:
        return jsonify({"error": "report_id query parameter is required"}), 400
        
    try:
        db_report_id = uuid.UUID(str(report_id))
    except ValueError:
        return jsonify({"error": "Invalid report_id format"}), 400
        
    report = Report.query.get_or_404(db_report_id)
    
    # Validation
    if role == 'MANAGER' and str(report.manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Report belongs to another manager"}), 403
        
    followups = Followup.query.filter_by(report_id=db_report_id).order_by(Followup.created_at.asc()).all()
    return jsonify([f.to_dict() for f in followups]), 200

@followups_bp.route('', methods=['POST'])
@role_required('MANAGER')
def create_followup():
    import uuid
    role, user_id = get_current_user_role_and_id()
    data = request.get_json() or {}
    
    report_id = data.get('report_id')
    notes = data.get('notes')
    
    if not report_id or not notes:
        return jsonify({"error": "report_id and notes are required"}), 400
        
    try:
        db_report_id = uuid.UUID(str(report_id))
    except ValueError:
        return jsonify({"error": "Invalid report_id format"}), 400
        
    report = Report.query.get_or_404(db_report_id)
    
    # Verify ownership
    if str(report.manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Report belongs to another manager"}), 403
        
    followup = Followup(
        report_id=db_report_id,
        manager_id=user_id,
        notes=notes
    )
    
    # Automatically update report status if it was open or change to pending
    if report.status == 'open':
        report.status = 'followup_pending'
        
    db.session.add(followup)
    db.session.commit()
    
    # Audit log
    log_action(
        action="Followup Creation",
        user_id=user_id,
        entity_type="followups",
        entity_id=followup.id,
        new_value=followup.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(followup.to_dict()), 201
