class DailyTargetModel {
  final String id;
  final int targetContacts;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyTargetModel({
    required this.id,
    required this.targetContacts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyTargetModel.fromJson(Map<String, dynamic> json) {
    return DailyTargetModel(
      id: json['id'] as String,
      targetContacts: json['target_contacts'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_contacts': targetContacts,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class DailySummaryModel {
  final int targetContacts;
  final int actualContactsHandled;
  final int progressPercentage;
  final int reportsCountToday;
  final bool metTarget;
  final String date;

  DailySummaryModel({
    required this.targetContacts,
    required this.actualContactsHandled,
    required this.progressPercentage,
    required this.reportsCountToday,
    required this.metTarget,
    required this.date,
  });

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    return DailySummaryModel(
      targetContacts: json['target_contacts'] as int,
      actualContactsHandled: json['actual_contacts_handled'] as int,
      progressPercentage: json['progress_percentage'] as int,
      reportsCountToday: json['reports_count_today'] as int,
      metTarget: json['met_target'] as bool,
      date: json['date'] as String,
    );
  }
}
