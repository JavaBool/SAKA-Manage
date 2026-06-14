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
