import os
import secrets

class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key-12345")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "jwt-dev-secret-key-12345")
    
    # SQLite fallback for local development if PostgreSQL is not available
    # Using an absolute path to the root 'instance' folder to prevent relative path mismatches
    _default_db_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "instance", "saka_manage.db"))
    os.makedirs(os.path.dirname(_default_db_path), exist_ok=True)
    db_url = os.environ.get("DATABASE_URL", f"sqlite:///{_default_db_path}")
    
    # Postgres compatibility (Railway sometimes outputs postgres:// instead of postgresql://)
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)
    
    SQLALCHEMY_DATABASE_URI = db_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Mail Config (Flask-Mail)
    MAIL_SERVER = os.environ.get("MAIL_SERVER", "localhost")
    MAIL_PORT = int(os.environ.get("MAIL_PORT", 8025))
    MAIL_USE_TLS = os.environ.get("MAIL_USE_TLS", "false").lower() in ("true", "1", "yes")
    MAIL_USE_SSL = os.environ.get("MAIL_USE_SSL", "false").lower() in ("true", "1", "yes")
    MAIL_USERNAME = os.environ.get("MAIL_USERNAME")
    MAIL_PASSWORD = os.environ.get("MAIL_PASSWORD")
    MAIL_DEFAULT_SENDER = os.environ.get("MAIL_DEFAULT_SENDER", "noreply@saka-manage.com")
    
    # Firebase Cloud Messaging Config
    # If provided as raw JSON string in environment variable, we will write it to a temp file or initialize directly
    FIREBASE_SERVICE_ACCOUNT_JSON = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    
    # Storage Config
    UPLOAD_FOLDER = os.environ.get("UPLOAD_FOLDER", os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads"))
    
    # Make sure upload folder exists
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
