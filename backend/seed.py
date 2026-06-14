import sys
import os

# Ensure the root project folder is in python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app import app
from backend.models.database import db
from backend.models.models import User, Contact, Product, Report, Followup

def seed_data():
    with app.app_context():
        # Create all tables (for local development SQLite environments)
        db.create_all()
        
        # Check if users exist already
        if User.query.first():
            print("Database already seeded.")
            return
            
        print("Seeding database...")
        
        # 1. Create Bosses
        boss1 = User(
            username="boss1",
            email="boss1@saka-manage.com",
            phone="+111222333",
            role="BOSS",
            active=True
        )
        boss1.set_password("boss123")
        db.session.add(boss1)
        
        # 2. Create Managers
        mgr1 = User(
            username="mgr1",
            email="mgr1@saka-manage.com",
            phone="+444555666",
            role="MANAGER",
            active=True
        )
        mgr1.set_password("mgr123")
        db.session.add(mgr1)
        
        mgr2 = User(
            username="mgr2",
            email="mgr2@saka-manage.com",
            phone="+777888999",
            role="MANAGER",
            active=True
        )
        mgr2.set_password("mgr123")
        db.session.add(mgr2)
        
        db.session.flush() # Flush to generate primary keys
        
        # 3. Create Products
        p1 = Product(name="SAKA Analytics Suite", description="Big data analytics dashboard engine.", active=True)
        p2 = Product(name="SAKA Portal", description="Customer web portal engine.", active=True)
        p3 = Product(name="SAKA Mobile App", description="Mobile tracking client.", active=True)
        db.session.add_all([p1, p2, p3])
        db.session.flush()
        
        # 4. Create Contacts
        c1 = Contact(
            name="Alice Johnson",
            company="Astra Group",
            designation="CTO",
            phone="+1998877",
            email="alice@astra.com",
            address="100 Innovation Way, Austin, TX",
            website="https://www.astragroup.com",
            assigned_manager_id=mgr1.id
        )
        c2 = Contact(
            name="Bob Miller",
            company="Nexus Inc",
            designation="Sales VP",
            phone="+1223344",
            email="bob@nexus.com",
            address="500 Tech Blvd, Seattle, WA",
            website="https://www.nexus.com",
            assigned_manager_id=mgr1.id
        )
        c3 = Contact(
            name="Charlie Davis",
            company="Summit Corp",
            designation="IT Director",
            phone="+1556677",
            email="charlie@summit.com",
            address="700 Mountain Ave, Denver, CO",
            website="https://www.summitcorp.com",
            assigned_manager_id=mgr2.id
        )
        db.session.add_all([c1, c2, c3])
        db.session.flush()
        
        # 5. Create Reports
        r1 = Report(
            contact_id=c1.id,
            manager_id=mgr1.id,
            product_id=p1.id,
            feedback_type="complaint",
            summary="Slow dashboard render times",
            details="Customer reports that large chart dashboard views exceed 8 seconds to fetch and render. This affects their daily monitoring speed.",
            priority="high",
            status="open"
        )
        r2 = Report(
            contact_id=c2.id,
            manager_id=mgr1.id,
            product_id=p2.id,
            feedback_type="feature_request",
            summary="Add PDF export to dashboard",
            details="Customer requested the ability to download full PDF reports directly from the main view.",
            priority="medium",
            status="followup_pending"
        )
        r3 = Report(
            contact_id=c3.id,
            manager_id=mgr2.id,
            product_id=p3.id,
            feedback_type="positive",
            summary="Mobile app is very responsive",
            details="Customer was impressed with the fluid transitions and low CPU footprint of the mobile tracking app.",
            priority="low",
            status="closed"
        )
        db.session.add_all([r1, r2, r3])
        db.session.flush()
        
        # 6. Add Followups
        f1 = Followup(
            report_id=r2.id,
            manager_id=mgr1.id,
            notes="Sent the specification guidelines to the product design team for feasibility review."
        )
        db.session.add(f1)
        
        db.session.commit()
        print("Database seeded successfully with test dataset.")

if __name__ == '__main__':
    seed_data()
