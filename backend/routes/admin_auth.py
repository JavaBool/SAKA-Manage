import time
import secrets
from flask import Blueprint, request, jsonify, session
from werkzeug.security import check_password_hash
from backend.config.admin_config import ADMIN_EMAIL, ADMIN_PASSWORD_HASH
from backend.services.email_service import send_otp_email
from backend.services.audit_service import log_action
from flask_jwt_extended import create_access_token

admin_auth_bp = Blueprint('admin_auth', __name__)

# In-memory store for OTPs: { email: { 'otp': '123456', 'expires': timestamp } }
otp_store = {}

@admin_auth_bp.route('/login', methods=['POST'])
def admin_login():
    data = request.get_json() or {}
    email = data.get('email')
    password = data.get('password')
    
    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400
        
    if email != ADMIN_EMAIL:
        # Avoid timing attacks
        check_password_hash(ADMIN_PASSWORD_HASH, "dummy")
        log_action(
            action="Admin Login Failed",
            user_id=None,
            entity_type="auth",
            old_value={"email": email, "reason": "invalid_email"},
            ip_address=request.remote_addr
        )
        return jsonify({"error": "Invalid credentials"}), 401
        
    if not check_password_hash(ADMIN_PASSWORD_HASH, password):
        log_action(
            action="Admin Login Failed",
            user_id=None,
            entity_type="auth",
            old_value={"email": email, "reason": "invalid_password"},
            ip_address=request.remote_addr
        )
        return jsonify({"error": "Invalid credentials"}), 401
        
    # Generate 6-digit OTP
    otp = "".join([str(secrets.randbelow(10)) for _ in range(6)])
    expires_at = time.time() + 600  # 10 minutes validity
    
    otp_store[email] = {
        'otp': otp,
        'expires': expires_at
    }
    
    # Send OTP by Email
    send_otp_email(email, otp)
    
    log_action(
        action="Admin OTP Generated",
        user_id=None,
        entity_type="auth",
        new_value={"email": email},
        ip_address=request.remote_addr
    )
    
    return jsonify({"message": "OTP code sent to email"}), 200

@admin_auth_bp.route('/verify-otp', methods=['POST'])
def admin_verify_otp():
    data = request.get_json() or {}
    email = data.get('email')
    otp = data.get('otp')
    
    if not email or not otp:
        return jsonify({"error": "Email and OTP are required"}), 400
        
    if email != ADMIN_EMAIL:
        return jsonify({"error": "Invalid request"}), 400
        
    entry = otp_store.get(email)
    if not entry:
        return jsonify({"error": "No pending OTP request. Please login again."}), 400
        
    if time.time() > entry['expires']:
        otp_store.pop(email, None)
        return jsonify({"error": "OTP has expired"}), 400
        
    if entry['otp'] != otp:
        log_action(
            action="Admin OTP Verification Failed",
            user_id=None,
            entity_type="auth",
            old_value={"email": email, "reason": "wrong_otp"},
            ip_address=request.remote_addr
        )
        return jsonify({"error": "Invalid OTP code"}), 401
        
    # OTP verified, remove entry
    otp_store.pop(email, None)
    
    # Generate JWT token for API access
    access_token = create_access_token(
        identity="admin-identity",
        additional_claims={"role": "ADMIN", "email": ADMIN_EMAIL}
    )
    
    # Also save admin in Flask session cookie for Admin Web Dashboard
    session.clear()
    session['admin_logged_in'] = True
    session['admin_email'] = ADMIN_EMAIL
    session['role'] = 'ADMIN'
    
    log_action(
        action="Login",
        user_id=None,
        entity_type="auth",
        new_value={"email": email, "role": "ADMIN"},
        ip_address=request.remote_addr
    )
    
    return jsonify({
        "message": "Login successful",
        "access_token": access_token,
        "role": "ADMIN"
    }), 200
