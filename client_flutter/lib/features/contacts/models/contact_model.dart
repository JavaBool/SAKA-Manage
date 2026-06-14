class ContactModel {
  final String id;
  final String name;
  final String? company;
  final String? designation;
  final String? phone;
  final String? email;
  final String? address;
  final String? assignedManagerId;

  ContactModel({
    required this.id,
    required this.name,
    this.company,
    this.designation,
    this.phone,
    this.email,
    this.address,
    this.assignedManagerId,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      company: json['company'] as String?,
      designation: json['designation'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      assignedManagerId: json['assigned_manager_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'designation': designation,
      'phone': phone,
      'email': email,
      'address': address,
      'assigned_manager_id': assignedManagerId,
    };
  }
}
