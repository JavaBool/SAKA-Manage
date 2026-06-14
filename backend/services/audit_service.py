import json
import uuid
import sys
from backend.models.database import db
from backend.models.models import AuditLog

def log_action(action, user_id=None, entity_type=None, entity_id=None, old_value=None, new_value=None, ip_address=None):
    """
    Log an action into the audit_logs table.
    Records are immutable.
    """
    try:
        old_val_str = None
        new_val_str = None
        
        if old_value is not None:
            if isinstance(old_value, str):
                old_val_str = old_value
            else:
                old_val_str = json.dumps(old_value)
                
        if new_value is not None:
            if isinstance(new_value, str):
                new_val_str = new_value
            else:
                new_val_str = json.dumps(new_value)

        # Safe UUID conversions for SQL database columns
        db_user_id = None
        if user_id:
            if isinstance(user_id, uuid.UUID):
                db_user_id = user_id
            else:
                try:
                    db_user_id = uuid.UUID(str(user_id))
                except ValueError:
                    # Non-standard UUID string (e.g. 'admin-identity') falls back to Admin UUID
                    db_user_id = uuid.UUID('00000000-0000-0000-0000-000000000000')

        db_entity_id = None
        if entity_id:
            if isinstance(entity_id, uuid.UUID):
                db_entity_id = entity_id
            else:
                try:
                    db_entity_id = uuid.UUID(str(entity_id))
                except ValueError:
                    pass

        log = AuditLog(
            user_id=db_user_id,
            action=action,
            entity_type=entity_type,
            entity_id=db_entity_id,
            old_value_json=old_val_str,
            new_value_json=new_val_str,
            ip_address=ip_address
        )
        db.session.add(log)
        db.session.commit()
        return log
    except Exception as e:
        db.session.rollback()
        # Log to server console
        print(f"Error writing audit log: {str(e)}", file=sys.stderr)
        return None
