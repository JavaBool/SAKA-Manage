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
    
    try:
        user_id = get_jwt_identity()
        user_uuid = uuid.UUID(user_id) if isinstance(user_id, str) else user_id
        
        data = request.get_json() or {}
        
        platform = data.get('platform')
        fcm_token = data.get('fcm_token')
        device_id = data.get('device_id')
        
        print(f"[DEVICE_TOKEN_DEBUG] Received token registration: user_id={user_id}, platform={platform}, device_id={device_id}, fcm_token={fcm_token}", flush=True)
        
        if not platform or not fcm_token or not device_id:
            print("[DEVICE_TOKEN_DEBUG] Missing required parameters.", flush=True)
            return jsonify({"error": "platform, fcm_token and device_id are required"}), 400
            
        # Search by fcm_token for ownership transfer
        existing = DeviceToken.query.filter_by(fcm_token=fcm_token).first()
        
        if existing:
            print(f"[DEVICE_TOKEN_DEBUG] Found existing token. Transferring ownership/updating user_id={user_id}", flush=True)
            existing.user_id = user_uuid
            existing.platform = platform
            existing.device_id = device_id
            existing.last_seen = func.now()
            db.session.commit()
            print("[DEVICE_TOKEN_DEBUG] Commit successful.", flush=True)
            return jsonify(existing.to_dict()), 200
            
        print(f"[DEVICE_TOKEN_DEBUG] Creating new device token mapping in DB.", flush=True)
        token = DeviceToken(
            user_id=user_uuid,
            platform=platform,
            fcm_token=fcm_token,
            device_id=device_id
        )
        db.session.add(token)
        db.session.commit()
        print("[DEVICE_TOKEN_DEBUG] Commit successful.", flush=True)
        
        return jsonify(token.to_dict()), 201
    except Exception as e:
        import traceback
        print(f"[DEVICE_TOKEN_DEBUG] Exception in register_token: {e}", flush=True)
        traceback.print_exc()
        db.session.rollback()
        return jsonify({"error": f"Internal server error during token registration: {str(e)}"}), 500
