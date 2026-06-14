class ReportModel {
  final String id;
  final String contactId;
  final String managerId;
  final String productId;
  final String feedbackType;
  final String summary;
  final String details;
  final String priority;
  final String status;
  final DateTime? nextFollowupDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Cache utility fields
  final String? contactName;
  final String? contactCompany;
  final String? productName;
  final String? managerUsername;

  ReportModel({
    required this.id,
    required this.contactId,
    required this.managerId,
    required this.productId,
    required this.feedbackType,
    required this.summary,
    required this.details,
    required this.priority,
    required this.status,
    this.nextFollowupDate,
    required this.createdAt,
    required this.updatedAt,
    this.contactName,
    this.contactCompany,
    this.productName,
    this.managerUsername,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      managerId: json['manager_id'] as String,
      productId: json['product_id'] as String,
      feedbackType: json['feedback_type'] as String,
      summary: json['summary'] as String,
      details: json['details'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      nextFollowupDate: json['next_followup_date'] != null
          ? DateTime.parse(json['next_followup_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      contactName: json['contact_name'] as String?,
      contactCompany: json['contact_company'] as String?,
      productName: json['product_name'] as String?,
      managerUsername: json['manager_username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'manager_id': managerId,
      'product_id': productId,
      'feedback_type': feedbackType,
      'summary': summary,
      'details': details,
      'priority': priority,
      'status': status,
      'next_followup_date': nextFollowupDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'contact_name': contactName,
      'contact_company': contactCompany,
      'product_name': productName,
      'manager_username': managerUsername,
    };
  }
}
