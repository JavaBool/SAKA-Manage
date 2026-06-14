import os
from werkzeug.security import generate_password_hash

# Admin email config
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "praveenkumar051207@gmail.com")

# Hashed admin password
# If ADMIN_PASSWORD is set in environment, hash it. Otherwise, use a default secure hash for "admin123"
_admin_raw_password = os.environ.get("ADMIN_PASSWORD", "admin123")
ADMIN_PASSWORD_HASH = generate_password_hash(_admin_raw_password)
