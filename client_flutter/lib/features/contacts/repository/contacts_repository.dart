import 'package:sqflite/sqflite.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/features/contacts/models/contact_model.dart';

class ContactsRepository {
  final ApiClient apiClient;

  ContactsRepository(this.apiClient);

  Future<List<ContactModel>> getContacts() async {
    try {
      final response = await apiClient.get('/contacts');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final contacts = data.map((json) => ContactModel.fromJson(json as Map<String, dynamic>)).toList();

        // Update cache
        final db = await DbHelper.database;
        await db.transaction((txn) async {
          await txn.delete('contacts');
          for (var contact in contacts) {
            await txn.insert(
              'contacts',
              contact.toJson(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        return contacts;
      }
    } catch (e) {
      print("Contacts fetch error, loading from local cache: $e");
    }

    // Fallback to SQLite cache
    return await _getCachedContacts();
  }

  Future<List<ContactModel>> _getCachedContacts() async {
    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps;
    if (ApiClient.userRole == 'MANAGER') {
      maps = await db.query(
        'contacts',
        where: 'assigned_manager_id = ?',
        whereArgs: [ApiClient.userId],
      );
    } else {
      maps = await db.query('contacts');
    }
    return maps.map((json) => ContactModel.fromJson(json)).toList();
  }

  Future<ContactModel?> getContactById(String id) async {
    try {
      final response = await apiClient.get('/contacts/$id');
      if (response.statusCode == 200) {
        final contact = ContactModel.fromJson(response.data as Map<String, dynamic>);
        final db = await DbHelper.database;
        await db.insert(
          'contacts',
          contact.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return contact;
      }
    } catch (e) {
      print("Error fetching single contact from API: $e");
    }

    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps;
    if (ApiClient.userRole == 'MANAGER') {
      maps = await db.query(
        'contacts',
        where: 'id = ? AND assigned_manager_id = ?',
        whereArgs: [id, ApiClient.userId],
        limit: 1,
      );
    } else {
      maps = await db.query(
        'contacts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
    }
    if (maps.isNotEmpty) {
      return ContactModel.fromJson(maps.first);
    }
    return null;
  }

  Future<bool> createContact(Map<String, dynamic> payload) async {
    try {
      final response = await apiClient.post('/contacts', data: payload);
      return response.statusCode == 201;
    } catch (e) {
      print("Error creating contact: $e");
      rethrow;
    }
  }

  Future<bool> updateContact(String id, Map<String, dynamic> payload) async {
    try {
      final response = await apiClient.put('/contacts/$id', data: payload);
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating contact: $e");
      rethrow;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      final response = await apiClient.delete('/contacts/$id');
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting contact: $e");
      rethrow;
    }
  }
}
