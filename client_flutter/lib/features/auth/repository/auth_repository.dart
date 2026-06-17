import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/features/auth/models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final storage = const FlutterSecureStorage();

  static String? token;

  AuthRepository(this.apiClient);

  Future<UserModel?> login(String username, String password) async {
    try {
      final response = await apiClient.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final String tokenVal = data['access_token'] as String;
        token = tokenVal;
        final userJson = data['user'] as Map<String, dynamic>;
        
        final user = UserModel.fromJson(userJson);

        // Save token & user metadata
        await storage.write(key: 'access_token', value: token);
        await storage.write(key: 'user_role', value: user.role);
        await storage.write(key: 'user_id', value: user.id);
        await storage.write(key: 'username', value: user.username);

        // Clear all previous user caches to prevent stale data leakage
        final db = await DbHelper.database;
        await db.delete('users');
        await db.delete('contacts');
        await db.delete('products');
        await db.delete('reports');
        await db.delete('followups');
        await db.delete('notifications');

        // Cache new user profile locally
        await db.insert(
          'users',
          user.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        return user;
      }
    } catch (e) {
      print("Login error: $e");
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout');
    } catch (e) {
      print("Logout API call error: $e");
    } finally {
      token = null;
      // Clear secure tokens
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'user_role');
      await storage.delete(key: 'user_id');
      await storage.delete(key: 'username');

      // Clear local caches
      final db = await DbHelper.database;
      await db.delete('users');
      await db.delete('contacts');
      await db.delete('products');
      await db.delete('reports');
      await db.delete('followups');
      await db.delete('notifications');
    }
  }

  Future<UserModel?> getCachedUser() async {
    token ??= await storage.read(key: 'access_token');
    final activeId = await storage.read(key: 'user_id');
    if (activeId == null) return null;
    
    try {
      final db = await DbHelper.database;
      final maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [activeId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return UserModel.fromJson(maps.first);
      }
    } catch (e) {
      print("Get cached user error: $e");
    }
    return null;
  }

  Future<void> registerDeviceToken(String fcmToken, String platform, String deviceId) async {
    try {
      final response = await apiClient.post('/device_tokens', data: {
        'platform': platform,
        'fcm_token': fcmToken,
        'device_id': deviceId,
      });
      print("[FCM_DEBUG] Token registration request successful. Status code: ${response.statusCode}");
    } catch (e) {
      if (e is DioException) {
        print("[FCM_DEBUG] Failed to register device token. Status: ${e.response?.statusCode}, Body: ${e.response?.data}");
      } else {
        print("[FCM_DEBUG] Failed to register device token. Error: $e");
      }
    }
  }
}
