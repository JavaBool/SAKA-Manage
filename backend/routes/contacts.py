from flask import Blueprint, request, jsonify
from backend.models.database import db
from backend.models.models import Contact
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action

contacts_bp = Blueprint('contacts', __name__)

@contacts_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_contacts():
    role, user_id = get_current_user_role_and_id()
    
    if role in ('ADMIN', 'BOSS'):
        contacts = Contact.query.all()
    else:  # MANAGER
        contacts = Contact.query.filter_by(assigned_manager_id=user_id).all()
        
    return jsonify([c.to_dict() for c in contacts]), 200

@contacts_bp.route('/<uuid:contact_id>', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_contact(contact_id):
    role, user_id = get_current_user_role_and_id()
    contact = Contact.query.get_or_404(contact_id)
    
    # Ownership validation for Managers
    if role == 'MANAGER' and str(contact.assigned_manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Contact not assigned to you"}), 403
        
    return jsonify(contact.to_dict()), 200

@contacts_bp.route('', methods=['POST'])
@role_required('ADMIN', 'BOSS')
def create_contact():
    import uuid
    role, user_id = get_current_user_role_and_id()
    data = request.get_json() or {}
    
    name = data.get('name')
    if not name:
        return jsonify({"error": "Name is required"}), 400
        
    assigned_mgr_id = data.get('assigned_manager_id')
    db_mgr_id = None
    if role == 'MANAGER':
        db_mgr_id = uuid.UUID(str(user_id))
    elif assigned_mgr_id:
        try:
            db_mgr_id = uuid.UUID(str(assigned_mgr_id))
        except ValueError:
            return jsonify({"error": "Invalid assigned_manager_id format"}), 400
        
    contact = Contact(
        name=name,
        company=data.get('company'),
        designation=data.get('designation'),
        phone=data.get('phone'),
        email=data.get('email'),
        address=data.get('address'),
        website=data.get('website'),
        assigned_manager_id=db_mgr_id
    )
    
    db.session.add(contact)
    db.session.commit()
    
    log_action(
        action="Contact Creation",
        user_id=user_id,
        entity_type="contacts",
        entity_id=contact.id,
        new_value=contact.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(contact.to_dict()), 201

@contacts_bp.route('/<uuid:contact_id>', methods=['PUT'])
@role_required('ADMIN', 'BOSS')
def update_contact(contact_id):
    import uuid
    role, user_id = get_current_user_role_and_id()
    contact = Contact.query.get_or_404(contact_id)
    data = request.get_json() or {}
    
    # Ownership validation for Managers
    if role == 'MANAGER' and str(contact.assigned_manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Contact not assigned to you"}), 403
        
    old_value = contact.to_dict()
    
    if 'name' in data:
        contact.name = data['name']
    if 'company' in data:
        contact.company = data['company']
    if 'designation' in data:
        contact.designation = data['designation']
    if 'phone' in data:
        contact.phone = data['phone']
    if 'email' in data:
        contact.email = data['email']
    if 'address' in data:
        contact.address = data['address']
    if 'website' in data:
        contact.website = data['website']
        
    if role != 'MANAGER' and 'assigned_manager_id' in data:
        assigned_mgr_id = data['assigned_manager_id']
        if assigned_mgr_id:
            try:
                contact.assigned_manager_id = uuid.UUID(str(assigned_mgr_id))
            except ValueError:
                return jsonify({"error": "Invalid assigned_manager_id format"}), 400
        else:
            contact.assigned_manager_id = None

    db.session.commit()
    
    log_action(
        action="Contact Update",
        user_id=user_id,
        entity_type="contacts",
        entity_id=contact.id,
        old_value=old_value,
        new_value=contact.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(contact.to_dict()), 200

@contacts_bp.route('/<uuid:contact_id>', methods=['DELETE'])
@role_required('ADMIN', 'BOSS')
def delete_contact(contact_id):
    role, user_id = get_current_user_role_and_id()
    contact = Contact.query.get_or_404(contact_id)
    
    # Ownership validation for Managers
    if role == 'MANAGER' and str(contact.assigned_manager_id) != str(user_id):
        return jsonify({"error": "Access forbidden: Contact not assigned to you"}), 403
        
    old_value = contact.to_dict()
    db.session.delete(contact)
    db.session.commit()
    
    log_action(
        action="Contact Delete",
        user_id=user_id,
        entity_type="contacts",
        entity_id=contact_id,
        old_value=old_value,
        ip_address=request.remote_addr
    )
    
    return jsonify({"message": "Contact deleted successfully"}), 200
