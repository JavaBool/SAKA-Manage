import os
from flask import Blueprint, jsonify, send_file, request
from backend.models.models import Attachment, Report
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.storage_service import get_storage_service

attachments_bp = Blueprint('attachments', __name__)

@attachments_bp.route('/<uuid:attachment_id>', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_attachment_info(attachment_id):
    role, user_id = get_current_user_role_and_id()
    attachment = Attachment.query.get_or_404(attachment_id)
    report = Report.query.get(attachment.report_id)
    
    if role == 'MANAGER' and report and str(report.manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Attachment belongs to another manager"}), 403
        
    return jsonify(attachment.to_dict()), 200

@attachments_bp.route('/<uuid:attachment_id>/download', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def download_attachment(attachment_id):
    role, user_id = get_current_user_role_and_id()
    attachment = Attachment.query.get_or_404(attachment_id)
    report = Report.query.get(attachment.report_id)
    
    if role == 'MANAGER' and report and str(report.manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Attachment belongs to another manager"}), 403
        
    storage = get_storage_service()
    try:
        abs_path = storage.get_absolute_path(attachment.filepath)
        if not os.path.exists(abs_path):
            return jsonify({"error": "File not found on server storage"}), 404
            
        return send_file(
            abs_path,
            mimetype=attachment.mime_type,
            as_attachment=True,
            download_name=attachment.filename
        )
    except Exception as e:
        return jsonify({"error": f"Failed to download file: {str(e)}"}), 500
