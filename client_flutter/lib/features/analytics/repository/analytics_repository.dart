import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/features/analytics/models/daily_target_model.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class AnalyticsRepository {
  final ApiClient apiClient;

  AnalyticsRepository(this.apiClient);

  Future<DailyTargetModel> getDailyTarget() async {
    try {
      final response = await apiClient.get('/analytics/daily-target');
      if (response.statusCode == 200) {
        final target = DailyTargetModel.fromJson(response.data as Map<String, dynamic>);
        
        // Save to local SQLite cache
        final db = await DbHelper.database;
        await db.insert(
          'daily_targets',
          target.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return target;
      }
    } catch (e) {
      print("Error fetching daily target online, loading from cache: $e");
    }

    // Fallback: load from local cache
    return await _getCachedDailyTarget();
  }

  Future<DailyTargetModel> _getCachedDailyTarget() async {
    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_targets',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return DailyTargetModel.fromJson(maps.first);
    }
    // Return default target if cache is also empty
    return DailyTargetModel(
      id: 'default',
      targetContacts: 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<DailyTargetModel> setDailyTarget(int targetContacts) async {
    final response = await apiClient.post('/analytics/daily-target', data: {
      'target_contacts': targetContacts,
    });
    if (response.statusCode == 200) {
      final target = DailyTargetModel.fromJson(response.data as Map<String, dynamic>);
      
      // Save to cache
      final db = await DbHelper.database;
      await db.insert(
        'daily_targets',
        target.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return target;
    }
    throw Exception("Failed to set daily target");
  }

  Future<DailySummaryModel> getDailySummary() async {
    final response = await apiClient.get('/analytics/daily-summary');
    if (response.statusCode == 200) {
      return DailySummaryModel.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception("Failed to fetch daily summary");
  }

  Future<bool> sendDailySummaryNotification() async {
    try {
      final response = await apiClient.post('/analytics/send-daily-summary');
      return response.statusCode == 200;
    } catch (e) {
      print("Failed to dispatch daily summary notification: $e");
      return false;
    }
  }
}
