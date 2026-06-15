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



# Initialize Firebase SDK
_fcm_initialized = False
_fcm_init_error = None
try:
    # Try getting default app
    firebase_admin.get_app()
    _fcm_initialized = True
except ValueError:
    # App doesn't exist, try initializing
    fcm_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if fcm_json:
        try:
            # Attempt to parse as JSON string first to initialize directly without temp files
            try:
                service_account_info = json.loads(fcm_json)
                cred = credentials.Certificate(service_account_info)
                firebase_admin.initialize_app(cred)
                _fcm_initialized = True
                print("Firebase Admin SDK initialized successfully via service account JSON dict.")
            except (json.JSONDecodeError, TypeError) as je:
                # Fallback to treating it as a filepath if it's not a valid JSON string
                if os.path.exists(fcm_json):
                    cred = credentials.Certificate(fcm_json)
                    firebase_admin.initialize_app(cred)
                    _fcm_initialized = True
                    print(f"Firebase Admin SDK initialized successfully via file path: {fcm_json}")
                else:
                    # Try using a temporary file as a last resort
                    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as temp_f:
                        temp_f.write(fcm_json)
                        temp_path = temp_f.name
                    
                    cred = credentials.Certificate(temp_path)
                    firebase_admin.initialize_app(cred)
                    _fcm_initialized = True
                    print("Firebase Admin SDK initialized successfully via temp file fallback.")
                    try:
                        os.unlink(temp_path)
                    except Exception:
                        pass
        except Exception as e:
            _fcm_init_error = f"Error initializing Firebase Admin: {str(e)}"
            print(_fcm_init_error, file=sys.stderr)
    else:
        _fcm_init_error = "Firebase Admin service account JSON not provided in environment."
        print(_fcm_init_error, file=sys.stderr)

def create_and_send_notification(recipient_user_id, title, message, entity_type=None, entity_id=None, return_summary=False):
    """
    Creates a notification entry in the database and sends a push notification via FCM.
    """
    import uuid
    if isinstance(recipient_user_id, str):
        recipient_user_id = uuid.UUID(recipient_user_id)
    if entity_id and isinstance(entity_id, str):
        entity_id = uuid.UUID(entity_id)

    token_count = 0
    success_count = 0
    failure_count = 0
    token_results = []
    exception_details = None
    notif = None

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

        # 2. Get device tokens
        tokens = [t.fcm_token for t in DeviceToken.query.filter_by(user_id=recipient_user_id).all()]
        tokens = list(set(tokens))
        token_count = len(tokens)
        if not tokens:
            dispatch_summary = {
                "token_count": 0,
                "success_count": 0,
                "failure_count": 0,
                "tokens": []
            }
            if return_summary:
                return notif, dispatch_summary
            return notif

        # 3. Send Push Notification
        if _fcm_initialized:
            try:
                # Prepare data payload (values must be strings)
                data_payload = {
                    "entity_type": str(entity_type) if entity_type else "",
                    "entity_id": str(entity_id) if entity_id else "",
                    "notification_id": str(notif.id) if notif else "",
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                }
                
                print(f"FCM sending attempt initiated: total target tokens = {token_count}")
                
                # Check if send_each_for_multicast is supported
                if hasattr(messaging, 'send_each_for_multicast'):
                    msg = messaging.MulticastMessage(
                        tokens=tokens,
                        notification=messaging.Notification(
                            title=title,
                            body=message
                        ),
                        data=data_payload
                    )
                    batch_response = messaging.send_each_for_multicast(msg)
                    success_count = batch_response.success_count
                    failure_count = batch_response.failure_count
                    
                    failures_list = []
                    for idx, resp in enumerate(batch_response.responses):
                        token = tokens[idx]
                        token_prefix = token[:15] + "..." if len(token) > 15 else token
                        if resp.success:
                            token_results.append({
                                "token": token_prefix,
                                "status": "success",
                                "message_id": resp.message_id
                            })
                            print(f"[FCM Success Log] Token: {token[:25]}... | Message ID: {resp.message_id}")
                        else:
                            err_str = str(resp.exception)
                            failures_list.append(f"Token: {token[:20]}... Error: {err_str}")
                            token_results.append({
                                "token": token_prefix,
                                "status": "failed",
                                "error": err_str
                            })
                            print(f"[FCM Failure Log] Token: {token[:25]}... | Exception: {err_str}", file=sys.stderr)
                            
                            # Check for token-not-found / unregistered errors
                            if isinstance(resp.exception, messaging.UnregisteredError):
                                print(f"[FCM Cleanup Log] Token is unregistered. Deleting token: {token[:25]}...", file=sys.stderr)
                                try:
                                    DeviceToken.query.filter_by(fcm_token=token).delete()
                                    db.session.commit()
                                    print(f"[FCM Cleanup Success] Successfully removed invalid token from DB: {token[:20]}...", file=sys.stderr)
                                except Exception as db_err:
                                    db.session.rollback()
                                    print(f"[FCM Cleanup Error] Failed to delete invalid token from DB: {str(db_err)}", file=sys.stderr)
                    
                    if failures_list:
                        exception_details = "\n".join(failures_list)
                else:
                    # Fallback to individual sends
                    for token in tokens:
                        token_prefix = token[:15] + "..." if len(token) > 15 else token
                        try:
                            msg = messaging.Message(
                                token=token,
                                notification=messaging.Notification(
                                    title=title,
                                    body=message
                                ),
                                data=data_payload
                            )
                            message_id = messaging.send(msg)
                            print(f"[FCM Success Log] Token: {token[:25]}... | Message ID: {message_id}")
                            token_results.append({
                                "token": token_prefix,
                                "status": "success",
                                "message_id": message_id
                            })
                            success_count += 1
                        except messaging.UnregisteredError as unreg_err:
                            failure_count += 1
                            err_msg = f"Token: {token[:20]}... Error (Unregistered): {str(unreg_err)}"
                            token_results.append({
                                "token": token_prefix,
                                "status": "failed",
                                "error": str(unreg_err)
                            })
                            print(f"[FCM Failure Log] {err_msg}", file=sys.stderr)
                            if exception_details:
                                exception_details += f"\n{err_msg}"
                            else:
                                exception_details = err_msg
                            
                            # Cleanup
                            print(f"[FCM Cleanup Log] Token is unregistered. Deleting token: {token[:25]}...", file=sys.stderr)
                            try:
                                DeviceToken.query.filter_by(fcm_token=token).delete()
                                db.session.commit()
                                print(f"[FCM Cleanup Success] Successfully removed invalid token from DB: {token[:20]}...", file=sys.stderr)
                            except Exception as db_err:
                                db.session.rollback()
                                print(f"[FCM Cleanup Error] Failed to delete invalid token from DB: {str(db_err)}", file=sys.stderr)
                        except Exception as token_err:
                            failure_count += 1
                            err_msg = f"Token: {token[:20]}... Error: {str(token_err)}"
                            token_results.append({
                                "token": token_prefix,
                                "status": "failed",
                                "error": str(token_err)
                            })
                            print(f"[FCM Failure Log] {err_msg}", file=sys.stderr)
                            if exception_details:
                                exception_details += f"\n{err_msg}"
                            else:
                                exception_details = err_msg
                    
                    print(f"FCM individual sends completed. Tokens: {token_count}, Successes: {success_count}, Failures: {failure_count}")
            except Exception as e:
                import traceback
                exception_details = traceback.format_exc()
                print(f"Failed to send FCM push notifications: {str(e)}\n{exception_details}", file=sys.stderr)
            
            # Detailed structured notification service run summary logging
            summary_log = (
                f"\n=== FCM NOTIFICATION DISPATCH RUN ===\n"
                f"Notification ID: {notif.id}\n"
                f"User ID        : {recipient_user_id}\n"
                f"Total Tokens   : {token_count}\n"
                f"Success Count  : {success_count}\n"
                f"Failure Count  : {failure_count}\n"
                f"Exception Logs : {exception_details or 'None'}\n"
                f"====================================="
            )
            print(summary_log)
        else:
            print(f"[Mock Push Notification] To User UUID: {recipient_user_id} | Title: {title} | Message: {message}")
            success_count = token_count
            failure_count = 0
            token_results = [
                {
                    "token": t[:15] + "..." if len(t) > 15 else t,
                    "status": "success",
                    "message_id": "mock-message-id"
                } for t in tokens
            ]

        dispatch_summary = {
            "token_count": token_count,
            "success_count": success_count,
            "failure_count": failure_count,
            "tokens": token_results,
            "exception_details": exception_details
        }
        if return_summary:
            return notif, dispatch_summary
        return notif
    except Exception as e:
        db.session.rollback()
        print(f"Error in create_and_send_notification: {str(e)}", file=sys.stderr)
        if return_summary:
            return None, {"error": str(e), "token_count": 0, "success_count": 0, "failure_count": 0, "tokens": []}
        return None

def notify_all_bosses(title, message, entity_type=None, entity_id=None):
    """
    Utility helper to notify all Bosses in the system.
    Returns detailed dispatch summaries for each Boss.
    """
    results = []
    try:
        bosses = User.query.filter_by(role='BOSS', active=True).all()
        for boss in bosses:
            notif, summary = create_and_send_notification(
                boss.id, title, message, entity_type, entity_id, return_summary=True
            )
            results.append({
                "username": boss.username,
                "user_id": str(boss.id),
                "notification_id": str(notif.id) if notif else None,
                "dispatch_summary": summary
            })
    except Exception as e:
        print(f"Error notifying bosses: {str(e)}", file=sys.stderr)
    return results



