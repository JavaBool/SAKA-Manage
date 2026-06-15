from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.models.database import db
from backend.models.models import DeviceToken
from backend.routes.decorators import role_required

device_tokens_bp = Blueprint('device_tokens', __name__)

@device_tokens_bp.route('', methods=['POST'])
@jwt_required()
def register_token():
    import uuid
    from sqlalchemy import func
    user_id = get_jwt_identity()
    user_uuid = uuid.UUID(user_id) if isinstance(user_id, str) else user_id
    
    data = request.get_json() or {}
    
    platform = data.get('platform')
    fcm_token = data.get('fcm_token')
    device_id = data.get('device_id')
    
    if not platform or not fcm_token or not device_id:
        return jsonify({"error": "platform, fcm_token and device_id are required"}), 400
        
    # Search by fcm_token for ownership transfer
    existing = DeviceToken.query.filter_by(fcm_token=fcm_token).first()
    
    if existing:
        existing.user_id = user_uuid
        existing.platform = platform
        existing.device_id = device_id
        existing.last_seen = func.now()
        db.session.commit()
        return jsonify(existing.to_dict()), 200
        
    token = DeviceToken(
        user_id=user_uuid,
        platform=platform,
        fcm_token=fcm_token,
        device_id=device_id
    )
    db.session.add(token)
    db.session.commit()
    
    return jsonify(token.to_dict()), 201
