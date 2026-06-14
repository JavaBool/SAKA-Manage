class FollowupModel {
  final String id;
  final String reportId;
  final String managerId;
  final String notes;
  final DateTime createdAt;
  final String? managerUsername;

  FollowupModel({
    required this.id,
    required this.reportId,
    required this.managerId,
    required this.notes,
    required this.createdAt,
    this.managerUsername,
  });

  factory FollowupModel.fromJson(Map<String, dynamic> json) {
    return FollowupModel(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      managerId: json['manager_id'] as String,
      notes: json['notes'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      managerUsername: json['manager_username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'manager_id': managerId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'manager_username': managerUsername,
    };
  }
}
