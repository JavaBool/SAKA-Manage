import os
import sys

# Ensure the parent directory of this file is in the python system path
# so that the 'backend' package imports resolve correctly in serverless/Vercel environments.
_root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from flask import Flask, redirect, url_for, jsonify, send_from_directory
from flask_jwt_extended import JWTManager
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
        <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@3.52.0/swagger-ui.css" >
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
        <script src="https://unpkg.com/swagger-ui-dist@3.52.0/swagger-ui-bundle.js"> </script>
        <script src="https://unpkg.com/swagger-ui-dist@3.52.0/swagger-ui-standalone-preset.js"> </script>
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

if __name__ == '__main__':
    # Default execution parameters
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
