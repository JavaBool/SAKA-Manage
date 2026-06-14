class NotificationModel {
  final String id;
  final String recipientUserId;
  final String title;
  final String message;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.message,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      recipientUserId: json['recipient_user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      isRead: json['is_read'] is bool
          ? json['is_read'] as bool
          : (json['is_read'] == 1 || json['is_read'] == true),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_user_id': recipientUserId,
      'title': title,
      'message': message,
      'entity_type': entityType,
      'entity_id': entityId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
