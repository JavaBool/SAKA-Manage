from flask import Blueprint, request, jsonify
from backend.models.database import db
from backend.models.models import User
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action

users_bp = Blueprint('users', __name__)

@users_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS')
def get_users():
    users = User.query.all()
    return jsonify([u.to_dict() for u in users]), 200

@users_bp.route('/<uuid:user_id>', methods=['GET'])
@role_required('ADMIN', 'BOSS')
def get_user(user_id):
    user = User.query.get_or_404(user_id)
    return jsonify(user.to_dict()), 200

@users_bp.route('', methods=['POST'])
@role_required('ADMIN')
def create_user():
    current_role, current_uid = get_current_user_role_and_id()
    data = request.get_json() or {}
    
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    role = data.get('role')  # BOSS, MANAGER
    phone = data.get('phone')
    
    if not username or not email or not password or not role:
        return jsonify({"error": "Username, email, password, and role are required"}), 400
        
    if role not in ('BOSS', 'MANAGER'):
        return jsonify({"error": "Role must be BOSS or MANAGER"}), 400
        
    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username already exists"}), 400
        
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "Email already exists"}), 400
        
    user = User(
        username=username,
        email=email,
        role=role,
        phone=phone,
        active=True
    )
    user.set_password(password)
    
    db.session.add(user)
    db.session.commit()
    
    # Audit log
    log_action(
        action="User Creation",
        user_id=current_uid,
        entity_type="users",
        entity_id=user.id,
        new_value=user.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(user.to_dict()), 201

@users_bp.route('/<uuid:user_id>', methods=['PUT'])
@role_required('ADMIN')
def update_user(user_id):
    current_role, current_uid = get_current_user_role_and_id()
    user = User.query.get_or_404(user_id)
    data = request.get_json() or {}
    
    old_value = user.to_dict()
    
    if 'username' in data:
        username = data['username']
        existing = User.query.filter_by(username=username).first()
        if existing and existing.id != user.id:
            return jsonify({"error": "Username already exists"}), 400
        user.username = username
        
    if 'email' in data:
        email = data['email']
        existing = User.query.filter_by(email=email).first()
        if existing and existing.id != user.id:
            return jsonify({"error": "Email already exists"}), 400
        user.email = email
        
    if 'phone' in data:
        user.phone = data['phone']
        
    if 'role' in data:
        role = data['role']
        if role not in ('BOSS', 'MANAGER'):
            return jsonify({"error": "Role must be BOSS or MANAGER"}), 400
        user.role = role
        
    if 'active' in data:
        user.active = bool(data['active'])
        
    if 'password' in data and data['password']:
        user.set_password(data['password'])
        
    db.session.commit()
    
    # Audit log
    log_action(
        action="User Update",
        user_id=current_uid,
        entity_type="users",
        entity_id=user.id,
        old_value=old_value,
        new_value=user.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(user.to_dict()), 200

@users_bp.route('/<uuid:user_id>', methods=['DELETE'])
@role_required('ADMIN')
def disable_user(user_id):
    """
    Disable user instead of hard deletion.
    """
    current_role, current_uid = get_current_user_role_and_id()
    user = User.query.get_or_404(user_id)
    
    old_value = user.to_dict()
    user.active = False
    db.session.commit()
    
    log_action(
        action="User Disable",
        user_id=current_uid,
        entity_type="users",
        entity_id=user.id,
        old_value=old_value,
        new_value=user.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify({"message": f"User {user.username} has been disabled", "user": user.to_dict()}), 200
