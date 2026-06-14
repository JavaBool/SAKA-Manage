from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.models.database import db
from backend.models.models import DeviceToken
from backend.routes.decorators import role_required

device_tokens_bp = Blueprint('device_tokens', __name__)

@device_tokens_bp.route('', methods=['POST'])
@jwt_required()
def register_token():
    user_id = get_jwt_identity()
    data = request.get_json() or {}
    
    platform = data.get('platform')
    fcm_token = data.get('fcm_token')
    
    if not platform or not fcm_token:
        return jsonify({"error": "platform and fcm_token are required"}), 400
        
    # Check if this token already exists for the user
    existing = DeviceToken.query.filter_by(user_id=user_id, fcm_token=fcm_token).first()
    if existing:
        # Just update platform/created_at if needed, but it's already there
        return jsonify(existing.to_dict()), 200
        
    token = DeviceToken(
        user_id=user_id,
        platform=platform,
        fcm_token=fcm_token
    )
    db.session.add(token)
    db.session.commit()
    
    return jsonify(token.to_dict()), 201
