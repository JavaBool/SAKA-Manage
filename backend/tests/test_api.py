import json
from io import BytesIO
from backend.models.models import AuditLog, Report, Followup

def test_user_login(client, seed_test_data):
    # Valid login
    resp = client.post('/api/v1/auth/login', json={
        'username': 'test_manager',
        'password': 'manager123'
    })
    assert resp.status_code == 200
    data = resp.get_json()
    assert 'access_token' in data
    assert data['role'] == 'MANAGER'
    
    # Invalid login
    resp = client.post('/api/v1/auth/login', json={
        'username': 'test_manager',
        'password': 'wrongpassword'
    })
    assert resp.status_code == 401

def test_admin_auth_flow(client):
    from backend.config.admin_config import ADMIN_EMAIL, _admin_raw_password
    # Step 1: Login
    resp = client.post('/api/v1/admin_auth/login', json={
        'email': ADMIN_EMAIL,
        'password': _admin_raw_password
    })
    assert resp.status_code == 200
    assert resp.get_json()['message'] == 'OTP code sent to email'
    
    # Check that OTP was written to console cache (which we can access by importing the store)
    from backend.routes.admin_auth import otp_store
    otp_entry = otp_store.get(ADMIN_EMAIL)
    assert otp_entry is not None
    otp = otp_entry['otp']
    # Verify incorrect OTP fails (do this before correct OTP clears the entry)
    resp = client.post('/api/v1/admin_auth/verify-otp', json={
        'email': ADMIN_EMAIL,
        'otp': '999999'
    })
    assert resp.status_code == 401

    # Step 2: Verify correct OTP
    resp = client.post('/api/v1/admin_auth/verify-otp', json={
        'email': ADMIN_EMAIL,
        'otp': otp
    })
    assert resp.status_code == 200
    data = resp.get_json()
    assert 'access_token' in data
    assert data['role'] == 'ADMIN'

def test_contacts_isolation(client, seed_test_data, manager_headers, boss_headers):
    # Manager should only see assigned contacts
    resp = client.get('/api/v1/contacts', headers=manager_headers)
    assert resp.status_code == 200
    data = resp.get_json()
    assert len(data) == 1
    assert data[0]['name'] == 'Contact Assigned'
    
    # Boss should see all contacts
    resp = client.get('/api/v1/contacts', headers=boss_headers)
    assert resp.status_code == 200
    data = resp.get_json()
    assert len(data) == 2

def test_products_endpoint(client, manager_headers):
    resp = client.get('/api/v1/products', headers=manager_headers)
    assert resp.status_code == 200
    assert len(resp.get_json()) == 1

def test_report_creation_and_audit(client, seed_test_data, manager_headers, db):
    # Create report with mock attachment
    data = {
        'contact_id': str(seed_test_data['contact_assigned'].id),
        'product_id': str(seed_test_data['product'].id),
        'feedback_type': 'complaint',
        'summary': 'New Slow Render Complaint',
        'details': 'Detailed description of slow renders',
        'priority': 'critical',
        'status': 'open',
        'next_followup_date': '2026-06-20T10:00:00Z',
        'attachments': (BytesIO(b"dummy file data"), "test_file.txt")
    }
    
    resp = client.post(
        '/api/v1/reports',
        headers=manager_headers,
        data=data,
        content_type='multipart/form-data'
    )
    
    assert resp.status_code == 201
    res_data = resp.get_json()
    assert res_data['summary'] == 'New Slow Render Complaint'
    
    # Verify Audit log was created
    audit = AuditLog.query.filter_by(action="Report Creation").first()
    assert audit is not None
    assert str(seed_test_data['manager'].id) == str(audit.user_id)
    assert audit.entity_type == "reports"

def test_report_creation_unassigned_contact(client, seed_test_data, manager_headers):
    # Try creating a report for a contact assigned to someone else
    data = {
        'contact_id': str(seed_test_data['contact_other'].id),
        'product_id': str(seed_test_data['product'].id),
        'feedback_type': 'complaint',
        'summary': 'Should Fail',
        'details': 'Failure test',
        'priority': 'low'
    }
    resp = client.post('/api/v1/reports', headers=manager_headers, json=data)
    assert resp.status_code == 403 or resp.status_code == 400

def test_report_edit_ownership(client, seed_test_data, manager_headers, boss_headers):
    report_id = seed_test_data['report'].id
    
    # Manager who owns report should be able to update it
    resp = client.put(f'/api/v1/reports/{report_id}', headers=manager_headers, json={
        'priority': 'critical',
        'summary': 'Updated summary'
    })
    assert resp.status_code == 200
    
    # Boss is not allowed to edit reports (only view)
    resp = client.put(f'/api/v1/reports/{report_id}', headers=boss_headers, json={
        'priority': 'low'
    })
    assert resp.status_code == 403

def test_followups(client, seed_test_data, manager_headers, db):
    report = seed_test_data['report']
    
    resp = client.post('/api/v1/followups', headers=manager_headers, json={
        'report_id': str(report.id),
        'notes': 'Spoke with the IT director. Working on hotfix.'
    })
    assert resp.status_code == 201
    
    # Verify followups list
    resp = client.get(f'/api/v1/followups?report_id={report.id}', headers=manager_headers)
    assert resp.status_code == 200
    assert len(resp.get_json()) == 1
    
    # Check that report status was automatically updated to followup_pending
    db.session.refresh(report)
    assert report.status == 'followup_pending'

def test_analytics(client, seed_test_data, boss_headers):
    resp = client.get('/api/v1/analytics', headers=boss_headers)
    assert resp.status_code == 200
    data = resp.get_json()
    assert 'metrics' in data
    assert 'charts' in data
    assert data['metrics']['total_reports'] == 1
