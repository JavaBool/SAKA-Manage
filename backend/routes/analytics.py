from datetime import datetime, timedelta, timezone
from flask import Blueprint, jsonify, request
from sqlalchemy import func
from flask_jwt_extended import get_jwt_identity
from backend.models.database import db
from backend.models.models import Report, User, Product, Followup, Contact, DailyTarget
from backend.routes.decorators import role_required

analytics_bp = Blueprint('analytics', __name__)

@analytics_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS')
def get_analytics():
    now = datetime.now(timezone.utc)
    today_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    week_start = today_start - timedelta(days=now.weekday())
    month_start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
    
    # KPIs
    total_reports = Report.query.count()
    reports_today = Report.query.filter(Report.created_at >= today_start).count()
    reports_this_week = Report.query.filter(Report.created_at >= week_start).count()
    reports_this_month = Report.query.filter(Report.created_at >= month_start).count()
    
    open_reports = Report.query.filter_by(status='open').count()
    closed_reports = Report.query.filter_by(status='closed').count()
    followup_pending_reports = Report.query.filter_by(status='followup_pending').count()
    
    critical_reports = Report.query.filter_by(priority='critical').count()
    
    # Followups due: next_followup_date is today or in the past, and status is not closed
    followups_due = Report.query.filter(
        Report.status != 'closed',
        Report.next_followup_date.isnot(None),
        Report.next_followup_date <= now
    ).count()
    
    active_managers = User.query.filter_by(role='MANAGER', active=True).count()
    
    # Charts data: Reports by Product
    reports_by_product_query = db.session.query(
        Product.name, func.count(Report.id)
    ).join(Report, Product.id == Report.product_id).group_by(Product.name).all()
    reports_by_product = {name: count for name, count in reports_by_product_query}
    
    # Reports by Manager
    reports_by_manager_query = db.session.query(
        User.username, func.count(Report.id)
    ).join(Report, User.id == Report.manager_id).group_by(User.username).all()
    reports_by_manager = {name: count for name, count in reports_by_manager_query}
    
    # Priority Distribution
    priority_query = db.session.query(
        Report.priority, func.count(Report.id)
    ).group_by(Report.priority).all()
    priority_dist = {pr: count for pr, count in priority_query}
    
    # Make sure all priority keys exist in response
    for key in ('low', 'medium', 'high', 'critical'):
        priority_dist.setdefault(key, 0)
        
    # Reports by Month (Last 6 Months)
    reports_by_month = {}
    for i in range(6):
        month_date = now - timedelta(days=30 * i)
        month_name = month_date.strftime("%B %Y")
        start_of_m = datetime(month_date.year, month_date.month, 1, tzinfo=timezone.utc)
        if month_date.month == 12:
            end_of_m = datetime(month_date.year + 1, 1, 1, tzinfo=timezone.utc)
        else:
            end_of_m = datetime(month_date.year, month_date.month + 1, 1, tzinfo=timezone.utc)
            
        count = Report.query.filter(Report.created_at >= start_of_m, Report.created_at < end_of_m).count()
        reports_by_month[month_name] = count
        
    # Feature Requests Trend (by feedback_type)
    fr_trend = {}
    complaint_trend = {}
    for i in range(6):
        month_date = now - timedelta(days=30 * i)
        month_name = month_date.strftime("%B %Y")
        start_of_m = datetime(month_date.year, month_date.month, 1, tzinfo=timezone.utc)
        if month_date.month == 12:
            end_of_m = datetime(month_date.year + 1, 1, 1, tzinfo=timezone.utc)
        else:
            end_of_m = datetime(month_date.year, month_date.month + 1, 1, tzinfo=timezone.utc)
            
        fr_count = Report.query.filter(
            Report.feedback_type == 'feature_request',
            Report.created_at >= start_of_m,
            Report.created_at < end_of_m
        ).count()
        
        comp_count = Report.query.filter(
            Report.feedback_type == 'complaint',
            Report.created_at >= start_of_m,
            Report.created_at < end_of_m
        ).count()
        
        fr_trend[month_name] = fr_count
        complaint_trend[month_name] = comp_count

    # Followup completion rate: closed reports / total reports * 100
    completion_rate = 100.0
    if total_reports > 0:
        completion_rate = round((closed_reports / total_reports) * 100, 1)
        
    return jsonify({
        "metrics": {
            "total_reports": total_reports,
            "reports_today": reports_today,
            "reports_this_week": reports_this_week,
            "reports_this_month": reports_this_month,
            "open_reports": open_reports,
            "closed_reports": closed_reports,
            "followup_pending_reports": followup_pending_reports,
            "critical_reports": critical_reports,
            "followups_due": followups_due,
            "active_managers": active_managers,
            "completion_rate": completion_rate
        },
        "charts": {
            "reports_by_product": reports_by_product,
            "reports_by_manager": reports_by_manager,
            "priority_distribution": priority_dist,
            "reports_by_month": reports_by_month,
            "feature_requests_trend": fr_trend,
            "complaint_trend": complaint_trend
        }
    }), 200

@analytics_bp.route('/daily-target', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_daily_target():
    target = DailyTarget.query.order_by(DailyTarget.created_at.desc()).first()
    if not target:
        target = DailyTarget(target_contacts=10)
        db.session.add(target)
        db.session.commit()
    return jsonify(target.to_dict()), 200

@analytics_bp.route('/daily-target', methods=['POST'])
@role_required('ADMIN', 'BOSS')
def set_daily_target():
    data = request.get_json() or {}
    target_contacts = data.get('target_contacts')
    if target_contacts is None:
        return jsonify({"error": "target_contacts parameter is required"}), 400
    try:
        target_contacts = int(target_contacts)
        if target_contacts < 1:
            raise ValueError
    except ValueError:
        return jsonify({"error": "target_contacts must be a positive integer"}), 400

    target = DailyTarget.query.order_by(DailyTarget.created_at.desc()).first()
    if not target:
        target = DailyTarget(target_contacts=target_contacts)
        db.session.add(target)
    else:
        target.target_contacts = target_contacts
    db.session.commit()

    # Log in audit
    user_id = get_jwt_identity()
    from backend.services.audit_service import log_action
    log_action(
        action="Set Daily Target",
        user_id=user_id,
        entity_type="daily_target",
        entity_id=target.id,
        new_value={"target_contacts": target_contacts}
    )

    return jsonify(target.to_dict()), 200

from backend.routes.decorators import api_key_or_role_required

@analytics_bp.route('/daily-summary', methods=['GET'])
@api_key_or_role_required('ADMIN', 'BOSS', 'MANAGER')
def get_daily_summary():
    # Retrieve latest daily target
    target = DailyTarget.query.order_by(DailyTarget.created_at.desc()).first()
    target_contacts = target.target_contacts if target else 10

    # Calculate actual contacts handled today
    now = datetime.now(timezone.utc)
    today_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    
    # Unique contacts for which reports were submitted today
    reports_today = Report.query.filter(Report.created_at >= today_start).order_by(Report.created_at.desc()).all()
    unique_contacts_today = {r.contact_id for r in reports_today}
    actual_contacts_handled = len(unique_contacts_today)
    
    progress_percentage = 0
    if target_contacts > 0:
        progress_percentage = min(100, int((actual_contacts_handled / target_contacts) * 100))

    return jsonify({
        "target_contacts": target_contacts,
        "actual_contacts_handled": actual_contacts_handled,
        "progress_percentage": progress_percentage,
        "reports_count_today": len(reports_today),
        "met_target": actual_contacts_handled >= target_contacts,
        "date": today_start.strftime("%Y-%m-%d"),
        "today_reports": [r.to_dict() for r in reports_today]
    }), 200

@analytics_bp.route('/send-daily-summary', methods=['POST'])
@api_key_or_role_required('ADMIN', 'BOSS')
def send_daily_summary_notification():
    # Calculate daily target and actuals
    target = DailyTarget.query.order_by(DailyTarget.created_at.desc()).first()
    target_contacts = target.target_contacts if target else 10

    now = datetime.now(timezone.utc)
    today_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
    
    reports_today = Report.query.filter(Report.created_at >= today_start).all()
    unique_contacts_today = {r.contact_id for r in reports_today}
    actual_contacts_handled = len(unique_contacts_today)

    status_str = "Met Target!" if actual_contacts_handled >= target_contacts else "Target Not Met"
    date_str = today_start.strftime("%B %d, %Y")

    title = f"Daily Summary: {date_str}"
    message = (
        f"Contacts handled today: {actual_contacts_handled}/{target_contacts} "
        f"({int((actual_contacts_handled/target_contacts)*100) if target_contacts > 0 else 0}%). "
        f"Status: {status_str}."
    )

    # Dispatch FCM summary to all bosses
    from backend.services.notification_service import notify_all_bosses
    dispatch_results = notify_all_bosses(
        title=title,
        message=message,
        entity_type="daily_target",
        entity_id=target.id if target else None
    )

    return jsonify({
        "success": True,
        "title": title,
        "message": message,
        "recipient_role": "BOSS",
        "dispatch_results": dispatch_results
    }), 200

