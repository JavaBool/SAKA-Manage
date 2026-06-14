import os
import sys
import json
import tempfile
import queue
import firebase_admin
from firebase_admin import credentials, messaging
from backend.models.database import db
from backend.models.models import User, DeviceToken, Notification, AuditLog
from backend.services.audit_service import log_action

# Server-Sent Events active push queues: mapping user_id (str) -> list of queue.Queue
sse_queues = {}

# Initialize Firebase SDK
_fcm_initialized = False
try:
    # Try getting default app
    firebase_admin.get_app()
    _fcm_initialized = True
except ValueError:
    # App doesn't exist, try initializing
    fcm_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if fcm_json:
        try:
            # We can write the json string to a temporary file
            with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as temp_f:
                temp_f.write(fcm_json)
                temp_path = temp_f.name
            
            cred = credentials.Certificate(temp_path)
            firebase_admin.initialize_app(cred)
            _fcm_initialized = True
            print("Firebase Admin SDK initialized successfully.")
            # Delete temporary file
            try:
                os.unlink(temp_path)
            except Exception:
                pass
        except Exception as e:
            print(f"Error initializing Firebase Admin: {str(e)}", file=sys.stderr)
    else:
        print("Firebase Admin service account JSON not provided in environment. Running in mock FCM mode.", file=sys.stderr)

def create_and_send_notification(recipient_user_id, title, message, entity_type=None, entity_id=None):
    """
    Creates a notification entry in the database and sends a push notification via FCM.
    """
    try:
        # 1. Save to DB
        notif = Notification(
            recipient_user_id=recipient_user_id,
            title=title,
            message=message,
            entity_type=entity_type,
            entity_id=entity_id,
            is_read=False
        )
        db.session.add(notif)
        db.session.commit()
        
        # Log notification delivery
        log_action(
            action="Notification Delivery",
            user_id=None,  # system action
            entity_type="notification",
            entity_id=notif.id,
            new_value={"recipient_id": str(recipient_user_id), "title": title}
        )

        # 1.5. Push to SSE active streams
        user_id_str = str(recipient_user_id)
        if user_id_str in sse_queues:
            notif_dict = notif.to_dict()
            for q in sse_queues[user_id_str]:
                try:
                    q.put(notif_dict)
                except Exception as sse_err:
                    print(f"Error putting to SSE queue: {str(sse_err)}", file=sys.stderr)

        # 2. Get device tokens
        tokens = [t.fcm_token for t in DeviceToken.query.filter_by(user_id=recipient_user_id).all()]
        if not tokens:
            return notif

        # 3. Send Push Notification
        if _fcm_initialized:
            try:
                # Prepare data payload (values must be strings)
                data_payload = {
                    "entity_type": str(entity_type) if entity_type else "",
                    "entity_id": str(entity_id) if entity_id else "",
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                }
                
                msg = messaging.MulticastMessage(
                    tokens=tokens,
                    notification=messaging.Notification(
                        title=title,
                        body=message
                    ),
                    data=data_payload
                )
                response = messaging.send_multicast(msg)
                print(f"Sent notifications via FCM. Success: {response.success_count}, Failure: {response.failure_count}")
            except Exception as e:
                print(f"Failed to send FCM push notification: {str(e)}", file=sys.stderr)
        else:
            print(f"[Mock Push Notification] To User UUID: {recipient_user_id} | Title: {title} | Message: {message}")

        return notif
    except Exception as e:
        db.session.rollback()
        print(f"Error in create_and_send_notification: {str(e)}", file=sys.stderr)
        return None

def notify_all_bosses(title, message, entity_type=None, entity_id=None):
    """
    Utility helper to notify all Bosses in the system.
    """
    try:
        bosses = User.query.filter_by(role='BOSS', active=True).all()
        for boss in bosses:
            create_and_send_notification(boss.id, title, message, entity_type, entity_id)
    except Exception as e:
        print(f"Error notifying bosses: {str(e)}", file=sys.stderr)
