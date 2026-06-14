import uuid
from datetime import datetime, timezone
from sqlalchemy.sql import func
from werkzeug.security import generate_password_hash, check_password_hash
from backend.models.database import db

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    phone = db.Column(db.String(20), nullable=True)
    password_hash = db.Column(db.String(256), nullable=False)
    role = db.Column(db.String(20), nullable=False)  # BOSS, MANAGER, ADMIN
    active = db.Column(db.Boolean, default=True, nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    last_login = db.Column(db.DateTime(timezone=True), nullable=True)

    # Relationships
    contacts = db.relationship('Contact', backref='manager', lazy=True)
    reports = db.relationship('Report', backref='manager', lazy=True)
    followups = db.relationship('Followup', backref='manager', lazy=True)
    notifications = db.relationship('Notification', backref='recipient', lazy=True)
    device_tokens = db.relationship('DeviceToken', backref='user', lazy=True)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
        
    def to_dict(self):
        return {
            'id': str(self.id),
            'username': self.username,
            'email': self.email,
            'phone': self.phone,
            'role': self.role,
            'active': self.active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'last_login': self.last_login.isoformat() if self.last_login else None
        }

class Contact(db.Model):
    __tablename__ = 'contacts'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    name = db.Column(db.String(100), nullable=False)
    company = db.Column(db.String(100), nullable=True)
    designation = db.Column(db.String(100), nullable=True)
    phone = db.Column(db.String(20), nullable=True)
    email = db.Column(db.String(120), nullable=True)
    address = db.Column(db.Text, nullable=True)
    website = db.Column(db.String(255), nullable=True)
    assigned_manager_id = db.Column(db.Uuid, db.ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    reports = db.relationship('Report', backref='contact', lazy=True)

    def to_dict(self):
        return {
            'id': str(self.id),
            'name': self.name,
            'company': self.company,
            'designation': self.designation,
            'phone': self.phone,
            'email': self.email,
            'address': self.address,
            'website': self.website,
            'assigned_manager_id': str(self.assigned_manager_id) if self.assigned_manager_id else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class Product(db.Model):
    __tablename__ = 'products'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    active = db.Column(db.Boolean, default=True, nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    reports = db.relationship('Report', backref='product', lazy=True)

    def to_dict(self):
        return {
            'id': str(self.id),
            'name': self.name,
            'description': self.description,
            'active': self.active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class Report(db.Model):
    __tablename__ = 'reports'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    contact_id = db.Column(db.Uuid, db.ForeignKey('contacts.id', ondelete='CASCADE'), nullable=False)
    manager_id = db.Column(db.Uuid, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    product_id = db.Column(db.Uuid, db.ForeignKey('products.id', ondelete='CASCADE'), nullable=False)
    feedback_type = db.Column(db.String(50), nullable=False)  # positive, negative, complaint, suggestion, feature_request
    summary = db.Column(db.String(255), nullable=False)
    details = db.Column(db.Text, nullable=False)
    priority = db.Column(db.String(20), nullable=False)  # low, medium, high, critical
    status = db.Column(db.String(20), default='open', nullable=False)  # open, followup_pending, closed
    next_followup_date = db.Column(db.DateTime(timezone=True), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    followups = db.relationship('Followup', backref='report', cascade='all, delete-orphan', lazy=True)
    attachments = db.relationship('Attachment', backref='report', cascade='all, delete-orphan', lazy=True)

    def to_dict(self):
        return {
            'id': str(self.id),
            'contact_id': str(self.contact_id),
            'manager_id': str(self.manager_id),
            'product_id': str(self.product_id),
            'feedback_type': self.feedback_type,
            'summary': self.summary,
            'details': self.details,
            'priority': self.priority,
            'status': self.status,
            'next_followup_date': self.next_followup_date.isoformat() if self.next_followup_date else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'contact_name': self.contact.name if self.contact else None,
            'contact_company': self.contact.company if self.contact else None,
            'product_name': self.product.name if self.product else None,
            'manager_username': self.manager.username if self.manager else None
        }

class Followup(db.Model):
    __tablename__ = 'followups'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    report_id = db.Column(db.Uuid, db.ForeignKey('reports.id', ondelete='CASCADE'), nullable=False)
    manager_id = db.Column(db.Uuid, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    notes = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'report_id': str(self.report_id),
            'manager_id': str(self.manager_id),
            'notes': self.notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'manager_username': self.manager.username if self.manager else None
        }

class Attachment(db.Model):
    __tablename__ = 'attachments'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    report_id = db.Column(db.Uuid, db.ForeignKey('reports.id', ondelete='CASCADE'), nullable=False)
    filename = db.Column(db.String(255), nullable=False)
    filepath = db.Column(db.String(512), nullable=False)
    mime_type = db.Column(db.String(100), nullable=False)
    size = db.Column(db.Integer, nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'report_id': str(self.report_id),
            'filename': self.filename,
            'mime_type': self.mime_type,
            'size': self.size,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Notification(db.Model):
    __tablename__ = 'notifications'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    recipient_user_id = db.Column(db.Uuid, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    message = db.Column(db.Text, nullable=False)
    entity_type = db.Column(db.String(50), nullable=True)  # report, followup, etc.
    entity_id = db.Column(db.Uuid, nullable=True)
    is_read = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'recipient_user_id': str(self.recipient_user_id),
            'title': self.title,
            'message': self.message,
            'entity_type': self.entity_type,
            'entity_id': str(self.entity_id) if self.entity_id else None,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class DeviceToken(db.Model):
    __tablename__ = 'device_tokens'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    user_id = db.Column(db.Uuid, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    platform = db.Column(db.String(50), nullable=False)  # android, windows, etc.
    fcm_token = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'user_id': str(self.user_id),
            'platform': self.platform,
            'fcm_token': self.fcm_token,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class AuditLog(db.Model):
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    user_id = db.Column(db.Uuid, nullable=True)  # Nullable for system or anonymous, otherwise string matching user or '00000000-0000-0000-0000-000000000000' for Admin
    action = db.Column(db.String(100), nullable=False)  # login, logout, create, update, delete
    entity_type = db.Column(db.String(50), nullable=True)
    entity_id = db.Column(db.Uuid, nullable=True)
    old_value_json = db.Column(db.Text, nullable=True)  # Store JSON representation as text
    new_value_json = db.Column(db.Text, nullable=True)
    ip_address = db.Column(db.String(45), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'user_id': str(self.user_id) if self.user_id else None,
            'action': self.action,
            'entity_type': self.entity_type,
            'entity_id': str(self.entity_id) if self.entity_id else None,
            'old_value_json': self.old_value_json,
            'new_value_json': self.new_value_json,
            'ip_address': self.ip_address,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class AdminOTP(db.Model):
    __tablename__ = 'admin_otps'
    email = db.Column(db.String(120), primary_key=True)
    otp = db.Column(db.String(6), nullable=False)
    expires_at = db.Column(db.Float, nullable=False)

    def to_dict(self):
        return {
            'email': self.email,
            'otp': self.otp,
            'expires_at': self.expires_at
        }

class DailyTarget(db.Model):
    __tablename__ = 'daily_targets'
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    target_contacts = db.Column(db.Integer, nullable=False, default=10)
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'target_contacts': self.target_contacts,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class APIKey(db.Model):
    __tablename__ = 'api_keys'
    id = db.Column(db.Uuid, primary_key=True, default=uuid.uuid4)
    name = db.Column(db.String(100), nullable=False)
    key = db.Column(db.String(256), unique=True, nullable=False)
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    enable_expiry = db.Column(db.Boolean, default=False, nullable=False)
    expires_at = db.Column(db.DateTime(timezone=True), nullable=True)
    allowed_endpoints = db.Column(db.JSON, nullable=False)  # list of allowed paths
    created_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    def to_dict(self):
        return {
            'id': str(self.id),
            'name': self.name,
            'key': self.key,
            'is_active': self.is_active,
            'enable_expiry': self.enable_expiry,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'allowed_endpoints': self.allowed_endpoints,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

