from flask import Blueprint, jsonify, request
from backend.models.database import db
from backend.models.models import Notification
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action

notifications_bp = Blueprint('notifications', __name__)

@notifications_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_notifications():
    role, user_id = get_current_user_role_and_id()
    
    # ADMIN notifications: since admin is not stored in DB, we could filter by the special Admin UUID
    # but the specification says admin can "View notifications" (likely all or none, we can return all or admin specifically)
    if role == 'ADMIN':
        notifications = Notification.query.order_by(Notification.created_at.desc()).all()
    else:
        notifications = Notification.query.filter_by(recipient_user_id=user_id).order_by(Notification.created_at.desc()).all()
        
    return jsonify([n.to_dict() for n in notifications]), 200

@notifications_bp.route('/<uuid:notification_id>/read', methods=['PUT'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def mark_read(notification_id):
    role, user_id = get_current_user_role_and_id()
    notification = Notification.query.get_or_404(notification_id)
    
    # Permission verification
    if role != 'ADMIN' and str(notification.recipient_user_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Notification belongs to another user"}), 403
        
    old_value = notification.to_dict()
    notification.is_read = True
    db.session.commit()
    
    return jsonify(notification.to_dict()), 200

@notifications_bp.route('/read-all', methods=['PUT'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def mark_all_read():
    role, user_id = get_current_user_role_and_id()
    
    if role == 'ADMIN':
        notifications = Notification.query.filter_by(is_read=False).all()
    else:
        notifications = Notification.query.filter_by(recipient_user_id=user_id, is_read=False).all()
        
    for n in notifications:
        n.is_read = True
        
    db.session.commit()
    return jsonify({"message": f"Marked {len(notifications)} notifications as read"}), 200

@notifications_bp.route('/diagnostics', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_diagnostics():
    from backend.services.notification_service import _fcm_initialized, _fcm_init_error
    from backend.models.models import DeviceToken
    import os
    
    db_type = db.engine.name
    tokens_count = DeviceToken.query.count()
    service_account_present = bool(os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON"))
    
    import firebase_admin
    try:
        firebase_admin.get_app()
        app_active = True
    except ValueError:
        app_active = False

    return jsonify({
        "fcm_initialized": _fcm_initialized,
        "fcm_init_error": _fcm_init_error,
        "firebase_app_active": app_active,
        "service_account_json_present": service_account_present,
        "database_type": db_type,
        "registered_device_tokens_count": tokens_count
    }), 200


