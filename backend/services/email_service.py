import sys
import socket
import os
import requests
from flask_mail import Mail, Message

# Shared Flask-Mail instance
mail = Mail()

def send_otp_email(recipient_email, otp):
    """
    Sends a 6-digit OTP code to the administrator.
    If RESEND_API_KEY is configured, uses Resend HTTP API to bypass blocked 
    SMTP ports on free hosting platforms (Render/Hugging Face).
    Otherwise, falls back to standard Flask-Mail (SMTP).
    """
    resend_api_key = os.environ.get("RESEND_API_KEY")
    if resend_api_key:
        try:
            # Use Resend's free onboarding sender if not overridden
            sender = os.environ.get("MAIL_DEFAULT_SENDER", "onboarding@resend.dev")
            
            headers = {
                "Authorization": f"Bearer {resend_api_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "from": sender,
                "to": [recipient_email],
                "subject": "SAKA-Manage Administrator Login OTP",
                "text": f"Your SAKA-Manage admin login OTP code is: {otp}\n\nThis code will expire in 10 minutes."
            }
            response = requests.post(
                "https://api.resend.com/emails",
                json=payload,
                headers=headers,
                timeout=10.0
            )
            if response.status_code in (200, 201):
                print(f"OTP email sent successfully via Resend API to {recipient_email}")
                return True
            else:
                print(f"Failed to send OTP email via Resend API: {response.text}", file=sys.stderr)
        except Exception as e:
            print(f"Resend API error: {str(e)}", file=sys.stderr)

    # Fallback to standard SMTP (Flask-Mail)
    old_timeout = socket.getdefaulttimeout()
    try:
        socket.setdefaulttimeout(10.0)
        msg = Message(
            subject="SAKA-Manage Administrator Login OTP",
            recipients=[recipient_email],
            body=f"Your SAKA-Manage admin login OTP code is: {otp}\n\nThis code will expire in 10 minutes."
        )
        mail.send(msg)
        print(f"OTP email sent successfully via SMTP to {recipient_email}")
        return True
    except Exception as e:
        print(f"Failed to send OTP email via SMTP: {str(e)}", file=sys.stderr)
        # Always output code in console logs as developer fallback
        print(f"[DEVELOPER/TESTER ALERT] OTP code for {recipient_email} is: {otp}", file=sys.stderr)
        return False
    finally:
        socket.setdefaulttimeout(old_timeout)
