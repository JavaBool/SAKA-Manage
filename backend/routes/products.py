from flask import Blueprint, request, jsonify
from backend.models.database import db
from backend.models.models import Product
from backend.routes.decorators import role_required, get_current_user_role_and_id
from backend.services.audit_service import log_action

products_bp = Blueprint('products', __name__)

@products_bp.route('', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_products():
    role, user_id = get_current_user_role_and_id()
    
    # Managers only see active products. Admins/Bosses see all.
    if role in ('ADMIN', 'BOSS'):
        products = Product.query.all()
    else:
        products = Product.query.filter_by(active=True).all()
        
    return jsonify([p.to_dict() for p in products]), 200

@products_bp.route('/<uuid:product_id>', methods=['GET'])
@role_required('ADMIN', 'BOSS', 'MANAGER')
def get_product(product_id):
    product = Product.query.get_or_404(product_id)
    return jsonify(product.to_dict()), 200

@products_bp.route('', methods=['POST'])
@role_required('ADMIN')
def create_product():
    role, user_id = get_current_user_role_and_id()
    data = request.get_json() or {}
    
    name = data.get('name')
    if not name:
        return jsonify({"error": "Product name is required"}), 400
        
    product = Product(
        name=name,
        description=data.get('description'),
        active=data.get('active', True)
    )
    
    db.session.add(product)
    db.session.commit()
    
    log_action(
        action="Product Creation",
        user_id=user_id,
        entity_type="products",
        entity_id=product.id,
        new_value=product.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(product.to_dict()), 201

@products_bp.route('/<uuid:product_id>', methods=['PUT'])
@role_required('ADMIN')
def update_product(product_id):
    role, user_id = get_current_user_role_and_id()
    product = Product.query.get_or_404(product_id)
    data = request.get_json() or {}
    
    old_value = product.to_dict()
    
    if 'name' in data:
        product.name = data['name']
    if 'description' in data:
        product.description = data['description']
    if 'active' in data:
        product.active = bool(data['active'])
        
    db.session.commit()
    
    log_action(
        action="Product Update",
        user_id=user_id,
        entity_type="products",
        entity_id=product.id,
        old_value=old_value,
        new_value=product.to_dict(),
        ip_address=request.remote_addr
    )
    
    return jsonify(product.to_dict()), 200

@products_bp.route('/<uuid:product_id>', methods=['DELETE'])
@role_required('ADMIN')
def delete_product(product_id):
    role, user_id = get_current_user_role_and_id()
    product = Product.query.get_or_404(product_id)
    
    old_value = product.to_dict()
    
    try:
        db.session.delete(product)
        db.session.commit()
    except Exception:
        db.session.rollback()
        # Fall back to making inactive if delete fails due to foreign key constraints
        product.active = False
        db.session.commit()
        
    log_action(
        action="Product Delete",
        user_id=user_id,
        entity_type="products",
        entity_id=product_id,
        old_value=old_value,
        ip_address=request.remote_addr
    )
    
    return jsonify({"message": "Product deleted/disabled successfully"}), 200
