from functools import wraps
from flask import request, jsonify, session
from flask_jwt_extended import verify_jwt_in_request, get_jwt, get_jwt_identity

def admin_required():
    """
    Decorator to restrict access to ADMIN only.
    Supports session-based auth (for admin web views) and JWT (for admin APIs).
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Check session (Jinja web views)
            if session.get('admin_logged_in') and session.get('role') == 'ADMIN':
                return f(*args, **kwargs)
            
            # Check JWT (APIs)
            try:
                verify_jwt_in_request()
                claims = get_jwt()
                if claims.get('role') == 'ADMIN':
                    return f(*args, **kwargs)
            except Exception:
                pass
                
            # If request is JSON API, return JSON
            if request.is_json or request.path.startswith('/api/'):
                return jsonify({"error": "Admin access required"}), 403
            # Otherwise, redirect to login page (dashboard)
            from flask import redirect, url_for
            return redirect(url_for('admin_db.login'))
        return decorated_function
    return decorator

def role_required(*roles):
    """
    Decorator to restrict access to specified roles.
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Check session for admin first
            if 'ADMIN' in roles and session.get('admin_logged_in') and session.get('role') == 'ADMIN':
                return f(*args, **kwargs)
                
            # Verify JWT in request
            try:
                verify_jwt_in_request()
                claims = get_jwt()
                user_role = claims.get('role')
            except Exception as e:
                import sys
                print(f"JWT Verification Failed: {str(e)}", file=sys.stderr)
                return jsonify({"error": "Authentication required"}), 401
                
            if user_role in roles:
                return f(*args, **kwargs)
                
            return jsonify({"error": f"Unauthorized. Required roles: {roles}"}), 403
        return decorated_function
    return decorator

def get_current_user_role_and_id():
    """
    Helper to extract role and user_id from either the current session or JWT token.
    Returns (role, user_id) where user_id is a uuid.UUID object or None.
    """
    import uuid
    if session.get('admin_logged_in') and session.get('role') == 'ADMIN':
        return 'ADMIN', uuid.UUID('00000000-0000-0000-0000-000000000000')
        
    try:
        # Check JWT (optional=True so it doesn't raise exception if missing)
        verify_jwt_in_request(optional=True)
        claims = get_jwt()
        if claims:
            return claims.get('role'), uuid.UUID(get_jwt_identity())
    except Exception:
        pass
        
    # Check session as fallback
    if session.get('admin_logged_in') and session.get('role') == 'ADMIN':
        return 'ADMIN', uuid.UUID('00000000-0000-0000-0000-000000000000')
        
    return None, None

def api_key_or_role_required(*roles):
    """
    Allows access either via a valid API Key matching the endpoint or via JWT matching the roles.
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            from backend.models.models import APIKey
            from datetime import datetime, timezone
            
            # 1. Try API Key verification first
            api_key_val = request.headers.get('X-API-Key')
            if api_key_val:
                key_obj = APIKey.query.filter_by(key=api_key_val, is_active=True).first()
                if key_obj:
                    # Check expiry
                    if key_obj.enable_expiry and key_obj.expires_at:
                        now = datetime.now(timezone.utc)
                        expires_at = key_obj.expires_at
                        if expires_at.tzinfo is None:
                            expires_at = expires_at.replace(tzinfo=timezone.utc)
                        if now > expires_at:
                            return jsonify({"error": "API Key has expired"}), 401
                    
                    # Check if request.path is allowed
                    path = request.path
                    allowed = False
                    for endpoint in key_obj.allowed_endpoints:
                        if path.rstrip('/') == endpoint.rstrip('/'):
                            allowed = True
                            break
                    if allowed:
                        return f(*args, **kwargs)
                    else:
                        return jsonify({"error": f"API Key not authorized for this endpoint: {path}"}), 403
                else:
                    return jsonify({"error": "Invalid API Key"}), 401

            # 2. Try session (for Admin page)
            if 'ADMIN' in roles and session.get('admin_logged_in') and session.get('role') == 'ADMIN':
                return f(*args, **kwargs)

            # 3. Fallback to JWT role verification
            try:
                verify_jwt_in_request()
                claims = get_jwt()
                user_role = claims.get('role')
                if user_role in roles:
                    return f(*args, **kwargs)
                return jsonify({"error": f"Unauthorized. Required roles: {roles}"}), 403
            except Exception as e:
                import sys
                print(f"JWT Verification Failed: {str(e)}", file=sys.stderr)
                return jsonify({"error": "Authentication or valid API Key required"}), 401

        return decorated_function
    return decorator

