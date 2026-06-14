class ProductModel {
  final String id;
  final String name;
  final String? description;
  final bool active;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.active,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      active: json['active'] is bool
          ? json['active'] as bool
          : (json['active'] == 1 || json['active'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'active': active ? 1 : 0,
    };
  }
}
