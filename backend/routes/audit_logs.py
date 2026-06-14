from flask import Blueprint, jsonify
from backend.models.models import AuditLog
from backend.routes.decorators import role_required

audit_logs_bp = Blueprint('audit_logs', __name__)

@audit_logs_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS')
def get_audit_logs():
    """
    Read-only view of the immutable system audit trail.
    """
    logs = AuditLog.query.order_by(AuditLog.created_at.desc()).all()
    return jsonify([log.to_dict() for log in logs]), 200
