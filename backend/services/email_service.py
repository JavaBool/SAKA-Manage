import sys
import socket
from flask_mail import Mail, Message

# Shared Flask-Mail instance
mail = Mail()

def send_otp_email(recipient_email, otp):
    """
    Sends a 6-digit OTP code to the administrator.
    If mail transmission fails (e.g. SMTP server not configured),
    prints the OTP code to standard error so developers can retrieve it from logs.
    """
    old_timeout = socket.getdefaulttimeout()
    try:
        # Set a short timeout for the email sending attempt to avoid hanging worker threads
        socket.setdefaulttimeout(10.0)
        
        msg = Message(
            subject="SAKA-Manage Administrator Login OTP",
            recipients=[recipient_email],
            body=f"Your SAKA-Manage admin login OTP code is: {otp}\n\nThis code will expire in 10 minutes."
        )
        mail.send(msg)
        print(f"OTP email sent successfully to {recipient_email}")
        return True
    except Exception as e:
        print(f"Failed to send OTP email: {str(e)}", file=sys.stderr)
        print(f"[DEVELOPER/TESTER ALERT] OTP code for {recipient_email} is: {otp}", file=sys.stderr)
        return False
    finally:
        socket.setdefaulttimeout(old_timeout)
