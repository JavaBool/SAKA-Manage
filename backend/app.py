import os
import sys

# Ensure the parent directory of this file is in the python system path
# so that the 'backend' package imports resolve correctly in serverless/Vercel environments.
_root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from flask import Flask, redirect, url_for, jsonify, send_from_directory, request
from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity
from flask_migrate import Migrate
from backend.config.config import Config
from backend.models.database import db
from backend.services.email_service import mail
from backend.routes.auth import auth_bp
from backend.routes.admin_auth import admin_auth_bp
from backend.routes.users import users_bp
from backend.routes.contacts import contacts_bp
from backend.routes.products import products_bp
from backend.routes.reports import reports_bp
from backend.routes.followups import followups_bp
from backend.routes.attachments import attachments_bp
from backend.routes.notifications import notifications_bp
from backend.routes.audit_logs import audit_logs_bp
from backend.routes.analytics import analytics_bp
from backend.routes.device_tokens import device_tokens_bp
from backend.routes.admin_dashboard import admin_db_bp

app = Flask(__name__)
app.config.from_object(Config)

# Initialize extensions
db.init_app(app)
migrate = Migrate(app, db)
jwt = JWTManager(app)
mail.init_app(app)

with app.app_context():
    try:
        from flask_migrate import upgrade, stamp
        inspector = db.inspect(db.engine)
        tables = inspector.get_table_names()
        
        if not tables or 'users' not in tables:
            print("Database is empty or missing core tables. Forcing a clean migration upgrade...", flush=True)
            if 'alembic_version' in tables:
                import sqlalchemy as sa
                db.session.execute(sa.text("DROP TABLE alembic_version"))
                db.session.commit()
            upgrade()
        else:
            if 'alembic_version' not in tables and 'users' in tables:
                print("Database tables exist but migration history is missing. Stamping to head...", flush=True)
                stamp(revision='head')
            
            print("Applying database migrations...", flush=True)
            upgrade()
            print("Database migrations applied successfully.", flush=True)
    except Exception as e:
        print(f"Warning: Database migration auto-application failed: {e}", file=sys.stderr, flush=True)
        try:
            db.create_all()
        except Exception as create_err:
            print(f"Critical: db.create_all fallback failed: {create_err}", file=sys.stderr, flush=True)

# Register Blueprints
app.register_blueprint(auth_bp, url_prefix='/api/v1/auth')
app.register_blueprint(admin_auth_bp, url_prefix='/api/v1/admin_auth')
app.register_blueprint(users_bp, url_prefix='/api/v1/users')
app.register_blueprint(contacts_bp, url_prefix='/api/v1/contacts')
app.register_blueprint(products_bp, url_prefix='/api/v1/products')
app.register_blueprint(reports_bp, url_prefix='/api/v1/reports')
app.register_blueprint(followups_bp, url_prefix='/api/v1/followups')
app.register_blueprint(attachments_bp, url_prefix='/api/v1/attachments')
app.register_blueprint(notifications_bp, url_prefix='/api/v1/notifications')
app.register_blueprint(audit_logs_bp, url_prefix='/api/v1/audit_logs')
app.register_blueprint(analytics_bp, url_prefix='/api/v1/analytics')
app.register_blueprint(device_tokens_bp, url_prefix='/api/v1/device_tokens')
app.register_blueprint(admin_db_bp, url_prefix='/admin')

# Add CORS headers
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

# Serve Swagger JSON
@app.route('/api/v1/swagger.json')
def serve_swagger_spec():
    # Return swagger.json from the project root or direct response
    return send_from_directory(os.path.dirname(__file__), 'swagger.json')

# Serve Swagger UI Docs
@app.route('/api/v1/docs')
def serve_swagger_ui():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>SAKA-Manage API Documentation</title>
        <link rel="icon" type="image/png" href="/static/swagger/favicon-32x32.png" sizes="32x32" />
        <link rel="icon" type="image/png" href="/static/swagger/favicon-16x16.png" sizes="16x16" />
        <link rel="stylesheet" type="text/css" href="/static/swagger/swagger-ui.css" >
        <style>
          html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
          *, *:before, *:after { box-sizing: inherit; }
          body { margin:0; background: #141821; color: #eceff4; }
          .swagger-ui .info .title { color: #8a4bf3 !important; }
          .swagger-ui .scheme-container { background: #1a1f2c !important; border-top: 1px solid rgba(255,255,255,0.08) !important; }
          .swagger-ui .opblock { border: 1px solid rgba(255,255,255,0.08) !important; }
          .swagger-ui .opblock-tag { color: #eceff4 !important; border-bottom: 1px solid rgba(255,255,255,0.08) !important; }
        </style>
    </head>
    <body>
        <div id="swagger-ui"></div>
        <script src="/static/swagger/swagger-ui-bundle.js"> </script>
        <script src="/static/swagger/swagger-ui-standalone-preset.js"> </script>
        <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: "/api/v1/swagger.json",
            dom_id: '#swagger-ui',
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            layout: "BaseLayout"
          });
          window.ui = ui;
        };
        </script>
    </body>
    </html>
    """

# Base redirect to admin dashboard login
@app.route('/')
def home():
    return redirect(url_for('admin_db.login'))

@app.route('/api/v1/test-push', methods=['POST'])
def test_push():
    from firebase_admin import messaging
    import firebase_admin
    
    data = request.get_json() or {}
    token = data.get('token')
    title = data.get('title', 'Test Notification')
    message = data.get('message', 'This is a test notification from SAKA-Manage backend.')
    
    if not token:
        return jsonify({
            "error": "token is required",
            "firebase_admin_version": firebase_admin.__version__
        }), 400
        
    # Check if Firebase has been initialized
    from backend.services.notification_service import _fcm_initialized, _fcm_init_error
    try:
        firebase_admin.get_app()
        fcm_initialized = True
    except ValueError:
        fcm_initialized = False

    if not fcm_initialized:
        # Running in Mock mode
        return jsonify({
            "success": True,
            "mock": True,
            "message": f"FCM is not initialized (no service account). {_fcm_init_error or ''}. Simulated push successfully.",
            "firebase_admin_version": firebase_admin.__version__,
            "logged": "Token count: 1, Success: 1 (Mocked), Failure: 0"
        }), 200
        
    try:
        data_payload = {
            "entity_type": "test",
            "entity_id": "",
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
        
        msg = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=title,
                body=message
            ),
            data=data_payload
        )
        
        message_id = messaging.send(msg)
        return jsonify({
            "success": True,
            "message_id": message_id,
            "firebase_admin_version": firebase_admin.__version__,
            "logged": "Token count: 1, Success: 1, Failure: 0"
        }), 200
    except Exception as e:
        import traceback
        tb = traceback.format_exc()
        return jsonify({
            "success": False,
            "error": str(e),
            "exception_details": tb,
            "firebase_admin_version": firebase_admin.__version__,
            "logged": "Token count: 1, Success: 0, Failure: 1"
        }), 500

@app.route('/api/v1/test-notification', methods=['POST'])
@jwt_required()
def test_notification():
    from backend.services.notification_service import create_and_send_notification
    import firebase_admin
    
    current_user_id = get_jwt_identity()
    
    data = request.get_json() or {}
    title = data.get('title', 'Test Push Notification')
    message = data.get('message', 'This is a test notification for the currently logged in user.')
    
    notif = create_and_send_notification(
        recipient_user_id=current_user_id,
        title=title,
        message=message,
        entity_type="test",
        entity_id=None
    )
    
    if notif:
        return jsonify({
            "success": True,
            "message": "Notification process completed.",
            "notification_id": str(notif.id),
            "recipient_user_id": str(current_user_id),
            "firebase_admin_version": firebase_admin.__version__
        }), 200
    else:
        return jsonify({
            "success": False,
            "error": "Failed to process notification."
        }), 500

if __name__ == '__main__':
    # Default execution parameters
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
