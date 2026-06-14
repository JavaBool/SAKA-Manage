import os
import sys
import pytest
from datetime import datetime, timezone

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app import app as flask_app
from backend.models.database import db as _db
from backend.models.models import User, Contact, Product, Report, Followup
from flask_jwt_extended import create_access_token

@pytest.fixture
def app():
    flask_app.config.update({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
        'JWT_SECRET_KEY': 'test-jwt-secret-key-12345',
        'MAIL_SUPPRESS_SEND': True,  # Suppress actual email transmission
        'UPLOAD_FOLDER': os.path.join(os.path.dirname(__file__), 'test_uploads')
    })
    
    os.makedirs(flask_app.config['UPLOAD_FOLDER'], exist_ok=True)
    
    with flask_app.app_context():
        _db.create_all()
        yield flask_app
        _db.session.remove()
        _db.drop_all()
        
    # clean up test upload folder
    import shutil
    try:
        shutil.rmtree(flask_app.config['UPLOAD_FOLDER'])
    except Exception:
        pass

@pytest.fixture
def client(app):
    return app.test_client()

@pytest.fixture
def db(app):
    return _db

@pytest.fixture
def seed_test_data(app, db):
    # Boss
    boss = User(username="test_boss", email="boss@test.com", role="BOSS", active=True)
    boss.set_password("boss123")
    
    # Manager
    manager = User(username="test_manager", email="manager@test.com", role="MANAGER", active=True)
    manager.set_password("manager123")
    
    # Another Manager
    other_manager = User(username="other_mgr", email="other@test.com", role="MANAGER", active=True)
    other_manager.set_password("manager123")
    
    db.session.add_all([boss, manager, other_manager])
    db.session.flush()
    
    # Product
    prod = Product(name="Test Product", description="Product for testing", active=True)
    db.session.add(prod)
    db.session.flush()
    
    # Contacts
    c1 = Contact(name="Contact Assigned", company="A Corp", email="c1@test.com", assigned_manager_id=manager.id)
    c2 = Contact(name="Contact Other", company="B Corp", email="c2@test.com", assigned_manager_id=other_manager.id)
    db.session.add_all([c1, c2])
    db.session.flush()
    
    # Report
    rep = Report(
        contact_id=c1.id,
        manager_id=manager.id,
        product_id=prod.id,
        feedback_type="complaint",
        summary="Test Report",
        details="Detail test notes",
        priority="high",
        status="open"
    )
    db.session.add(rep)
    db.session.commit()
    
    return {
        'boss': boss,
        'manager': manager,
        'other_manager': other_manager,
        'product': prod,
        'contact_assigned': c1,
        'contact_other': c2,
        'report': rep
    }

@pytest.fixture
def manager_headers(seed_test_data):
    token = create_access_token(
        identity=str(seed_test_data['manager'].id),
        additional_claims={"role": "MANAGER", "username": "test_manager"}
    )
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def boss_headers(seed_test_data):
    token = create_access_token(
        identity=str(seed_test_data['boss'].id),
        additional_claims={"role": "BOSS", "username": "test_boss"}
    )
    return {"Authorization": f"Bearer {token}"}
