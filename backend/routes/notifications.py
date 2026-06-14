from flask import Blueprint, jsonify, request, Response
import json
import queue
from backend.models.database import db
from backend.models.models import Notification
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action
from backend.services.notification_service import sse_queues

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

@notifications_bp.route('/stream', methods=['GET'])
def stream_notifications():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "user_id parameter is required"}), 400

    def event_generator():
        q = queue.Queue()
        user_id_str = str(user_id)
        
        # Register active queue
        if user_id_str not in sse_queues:
            sse_queues[user_id_str] = []
        sse_queues[user_id_str].append(q)
        
        try:
            # Yield initial connection confirmation
            yield f"data: {json.dumps({'status': 'connected'})}\n\n"
            
            while True:
                try:
                    notif_data = q.get(timeout=20.0)
                    yield f"data: {json.dumps(notif_data)}\n\n"
                except queue.Empty:
                    # Heartbeat comment to keep connection alive
                    yield ": heartbeat\n\n"
        except GeneratorExit:
            pass
        finally:
            # Unregister queue
            if user_id_str in sse_queues:
                if q in sse_queues[user_id_str]:
                    sse_queues[user_id_str].remove(q)
                if not sse_queues[user_id_str]:
                    del sse_queues[user_id_str]

    return Response(event_generator(), mimetype='text/event-stream')
