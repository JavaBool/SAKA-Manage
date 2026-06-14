from datetime import datetime, timezone
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, get_jwt
from sqlalchemy import func
from backend.models.database import db
from backend.models.models import User
from backend.services.audit_service import log_action

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400
        
    user = User.query.filter(
        (func.lower(User.username) == func.lower(username)) |
        (func.lower(User.email) == func.lower(username))
    ).first()
    
    if not user or not user.active:
        log_action(
            action="Login Failed",
            user_id=None,
            entity_type="auth",
            old_value={"username": username, "reason": "user_not_found_or_inactive"},
            ip_address=request.remote_addr
        )
        return jsonify({"error": "Invalid credentials"}), 401
        
    if not user.check_password(password):
        log_action(
            action="Login Failed",
            user_id=user.id,
            entity_type="auth",
            old_value={"username": username, "reason": "invalid_password"},
            ip_address=request.remote_addr
        )
        return jsonify({"error": "Invalid credentials"}), 401
        
    # Generate JWT
    access_token = create_access_token(
        identity=str(user.id),
        additional_claims={"role": user.role, "username": user.username}
    )
    
    # Update last login
    user.last_login = datetime.now(timezone.utc)
    db.session.commit()
    
    # Audit log
    log_action(
        action="Login",
        user_id=user.id,
        entity_type="users",
        entity_id=user.id,
        new_value={"username": user.username, "role": user.role},
        ip_address=request.remote_addr
    )
    
    return jsonify({
        "access_token": access_token,
        "role": user.role,
        "user": user.to_dict()
    }), 200

@auth_bp.route('/profile', methods=['GET'])
@jwt_required()
def profile():
    import uuid
    user_id = get_jwt_identity()
    try:
        db_user_id = uuid.UUID(user_id)
    except ValueError:
        return jsonify({"error": "Invalid identity format"}), 400
        
    user = User.query.get(db_user_id)
    if not user or not user.active:
        return jsonify({"error": "User not found or inactive"}), 404
    return jsonify(user.to_dict()), 200

@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    import uuid
    user_id = get_jwt_identity()
    db_user_id = None
    try:
        db_user_id = uuid.UUID(user_id)
    except ValueError:
        pass
        
    user = User.query.get(db_user_id) if db_user_id else None
    username = user.username if user else "unknown"
    
    log_action(
        action="Logout",
        user_id=db_user_id,
        entity_type="users",
        entity_id=db_user_id,
        old_value={"username": username},
        ip_address=request.remote_addr
    )
    return jsonify({"message": "Logout successful"}), 200
