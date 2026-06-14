import 'package:sqflite/sqflite.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/features/notifications/models/notification_model.dart';

class NotificationsRepository {
  final ApiClient apiClient;

  NotificationsRepository(this.apiClient);

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await apiClient.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final notifications = data.map((json) => NotificationModel.fromJson(json as Map<String, dynamic>)).toList();

        // Update local database cache
        final db = await DbHelper.database;
        await db.transaction((txn) async {
          await txn.delete('notifications');
          for (var n in notifications) {
            await txn.insert(
              'notifications',
              n.toJson(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        return notifications;
      }
    } catch (e) {
      print("Notifications fetch error, loading from local cache: $e");
    }

    return await _getCachedNotifications();
  }

  Future<List<NotificationModel>> _getCachedNotifications() async {
    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('notifications', orderBy: 'created_at DESC');
    return maps.map((json) => NotificationModel.fromJson(json)).toList();
  }

  Future<void> markAsRead(String notifId) async {
    final db = await DbHelper.database;
    
    // Update local cache immediately
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notifId],
    );

    try {
      await apiClient.put('/notifications/$notifId/read');
    } catch (e) {
      print("Error marking notification read online: $e");
      // Note: we can optionally queue this action, but since it's just read-state sync,
      // it will be corrected on the next full pull when online.
    }
  }

  Future<void> markAllAsRead() async {
    final db = await DbHelper.database;
    
    // Update local cache immediately
    await db.update('notifications', {'is_read': 1});

    try {
      await apiClient.put('/notifications/read-all');
    } catch (e) {
      print("Error marking all notifications read online: $e");
    }
  }
}
