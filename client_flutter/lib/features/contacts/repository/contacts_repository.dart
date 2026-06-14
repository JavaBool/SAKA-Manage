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
    final List<Map<String, dynamic>> maps = await db.query('contacts');
    return maps.map((json) => ContactModel.fromJson(json)).toList();
  }
}
