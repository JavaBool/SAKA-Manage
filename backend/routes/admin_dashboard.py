import os
import time
from flask import Blueprint, render_template, redirect, url_for, session, request, flash, current_app
from backend.models.database import db
from backend.models.models import User, Contact, Product, Report, Notification, AuditLog
from backend.routes.decorators import admin_required
from backend.config.admin_config import ADMIN_EMAIL

admin_db_bp = Blueprint('admin_db', __name__, template_folder='../templates')

@admin_db_bp.route('/login', methods=['GET', 'POST'])
def login():
    if session.get('admin_logged_in'):
        return redirect(url_for('admin_db.dashboard'))
    return render_template('login.html')

@admin_db_bp.route('/logout')
def logout():
    session.clear()
    flash("You have logged out.", "info")
    return redirect(url_for('admin_db.login'))

@admin_db_bp.route('/dashboard')
@admin_required()
def dashboard():
    # Fetch KPIs
    total_reports = Report.query.count()
    open_reports = Report.query.filter_by(status='open').count()
    critical_reports = Report.query.filter_by(priority='critical').count()
    total_users = User.query.count()
    
    # Recent reports
    recent_reports = Report.query.order_by(Report.created_at.desc()).limit(5).all()
    # Recent audits
    recent_audits = AuditLog.query.order_by(AuditLog.created_at.desc()).limit(5).all()
    
    return render_template(
        'dashboard.html',
        total_reports=total_reports,
        open_reports=open_reports,
        critical_reports=critical_reports,
        total_users=total_users,
        recent_reports=recent_reports,
        recent_audits=recent_audits
    )

@admin_db_bp.route('/users')
@admin_required()
def users():
    users_list = User.query.all()
    return render_template('users.html', users=users_list)

@admin_db_bp.route('/contacts')
@admin_required()
def contacts():
    contacts_list = Contact.query.all()
    # Fetch all managers for assignment dropdowns
    managers = User.query.filter_by(role='MANAGER', active=True).all()
    return render_template('contacts.html', contacts=contacts_list, managers=managers)

@admin_db_bp.route('/products')
@admin_required()
def products():
    products_list = Product.query.all()
    return render_template('products.html', products=products_list)

@admin_db_bp.route('/reports')
@admin_required()
def reports():
    reports_list = Report.query.order_by(Report.created_at.desc()).all()
    return render_template('reports.html', reports=reports_list)

@admin_db_bp.route('/notifications')
@admin_required()
def notifications():
    notifications_list = Notification.query.order_by(Notification.created_at.desc()).all()
    return render_template('notifications.html', notifications=notifications_list)

@admin_db_bp.route('/audit_logs')
@admin_required()
def audit_logs():
    logs = AuditLog.query.order_by(AuditLog.created_at.desc()).all()
    return render_template('audit_logs.html', logs=logs)

@admin_db_bp.route('/analytics')
@admin_required()
def analytics():
    return render_template('analytics.html')

@admin_db_bp.route('/settings')
@admin_required()
def settings():
    # Calculate health metrics
    db_healthy = True
    try:
        db.session.execute(db.text("SELECT 1"))
    except Exception:
        db_healthy = False
        
    upload_dir = current_app.config.get('UPLOAD_FOLDER', 'uploads')
    storage_size_mb = 0
    if os.path.exists(upload_dir):
        for dirpath, dirnames, filenames in os.walk(upload_dir):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                storage_size_mb += os.path.getsize(fp)
    storage_size_mb = round(storage_size_mb / (1024 * 1024), 2)
    
    server_time = time.strftime('%Y-%m-%d %H:%M:%S')
    
    return render_template(
        'settings.html',
        db_healthy=db_healthy,
        storage_size_mb=storage_size_mb,
        server_time=server_time,
        admin_email=ADMIN_EMAIL
    )

from backend.models.models import APIKey
import secrets
from datetime import datetime, timezone

@admin_db_bp.route('/api-keys')
@admin_required()
def api_keys():
    keys_list = APIKey.query.order_by(APIKey.created_at.desc()).all()
    # Provide a pre-generated secure token suggestion for convenience
    suggested_key = f"saka_key_{secrets.token_urlsafe(24)}"
    return render_template('api_keys.html', api_keys=keys_list, suggested_key=suggested_key)

@admin_db_bp.route('/api-keys/create', methods=['POST'])
@admin_required()
def create_api_key():
    name = request.form.get('name', '').strip()
    key_val = request.form.get('key', '').strip()
    enable_expiry = request.form.get('enable_expiry') == 'y'
    expires_at_str = request.form.get('expires_at', '').strip()
    allowed_endpoints = request.form.getlist('allowed_endpoints')

    if not name:
        flash("API Key Name is required.", "error")
        return redirect(url_for('admin_db.api_keys'))

    if not key_val:
        key_val = f"saka_key_{secrets.token_urlsafe(24)}"

    # Parse expiration date if enabled
    expires_at = None
    if enable_expiry and expires_at_str:
        try:
            # HTML datetime-local format: YYYY-MM-DDTHH:MM
            expires_at = datetime.fromisoformat(expires_at_str).replace(tzinfo=timezone.utc)
        except ValueError:
            flash("Invalid expiry date/time format.", "error")
            return redirect(url_for('admin_db.api_keys'))

    if not allowed_endpoints:
        flash("You must select at least one allowed endpoint.", "error")
        return redirect(url_for('admin_db.api_keys'))

    # Check for duplicate key value
    existing = APIKey.query.filter_by(key=key_val).first()
    if existing:
        flash("This API Key value already exists. Suggest regenerating a new key.", "error")
        return redirect(url_for('admin_db.api_keys'))

    new_key = APIKey(
        name=name,
        key=key_val,
        is_active=True,
        enable_expiry=enable_expiry,
        expires_at=expires_at,
        allowed_endpoints=allowed_endpoints
    )
    
    try:
        db.session.add(new_key)
        db.session.commit()
        
        # Log in audit log
        from backend.services.audit_service import log_action
        log_action(
            action="Create API Key",
            user_id=None,  # Admin action via dashboard
            entity_type="api_key",
            entity_id=new_key.id,
            new_value={"name": name, "allowed_endpoints": allowed_endpoints}
        )
        flash("API Key created successfully!", "success")
    except Exception as e:
        db.session.rollback()
        flash(f"Error creating API Key: {str(e)}", "error")

    return redirect(url_for('admin_db.api_keys'))

@admin_db_bp.route('/api-keys/<uuid:key_id>/toggle', methods=['POST'])
@admin_required()
def toggle_api_key(key_id):
    # Use Session.get() or query filter to get key
    key_obj = APIKey.query.get(key_id)
    if not key_obj:
        flash("API Key not found.", "error")
        return redirect(url_for('admin_db.api_keys'))
    key_obj.is_active = not key_obj.is_active
    try:
        db.session.commit()
        status_str = "activated" if key_obj.is_active else "deactivated"
        
        # Log audit
        from backend.services.audit_service import log_action
        log_action(
            action="Toggle API Key Status",
            user_id=None,
            entity_type="api_key",
            entity_id=key_obj.id,
            new_value={"is_active": key_obj.is_active}
        )
        flash(f"API Key successfully {status_str}!", "success")
    except Exception as e:
        db.session.rollback()
        flash(f"Error toggling status: {str(e)}", "error")
        
    return redirect(url_for('admin_db.api_keys'))

@admin_db_bp.route('/api-keys/<uuid:key_id>/delete', methods=['POST'])
@admin_required()
def delete_api_key(key_id):
    key_obj = APIKey.query.get(key_id)
    if not key_obj:
        flash("API Key not found.", "error")
        return redirect(url_for('admin_db.api_keys'))
    try:
        db.session.delete(key_obj)
        db.session.commit()
        
        # Log audit
        from backend.services.audit_service import log_action
        log_action(
            action="Delete API Key",
            user_id=None,
            entity_type="api_key",
            entity_id=key_id,
            new_value={"name": key_obj.name}
        )
        flash("API Key deleted successfully!", "success")
    except Exception as e:
        db.session.rollback()
        flash(f"Error deleting API Key: {str(e)}", "error")

    return redirect(url_for('admin_db.api_keys'))

