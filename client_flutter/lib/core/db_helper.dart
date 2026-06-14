import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class DbHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, "saka_manage.db");
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE contacts ADD COLUMN website TEXT');
    }
  }
  
  static Future<void> _onCreate(Database db, int version) async {
    // 1. Users Cache
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT,
        email TEXT,
        phone TEXT,
        role TEXT,
        active INTEGER,
        last_login TEXT
      )
    ''');
    
    // 2. Contacts Cache
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT,
        company TEXT,
        designation TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        website TEXT,
        assigned_manager_id TEXT
      )
    ''');

    // 3. Products Cache
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        active INTEGER
      )
    ''');

    // 4. Reports Cache
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        contact_id TEXT,
        manager_id TEXT,
        product_id TEXT,
        feedback_type TEXT,
        summary TEXT,
        details TEXT,
        priority TEXT,
        status TEXT,
        next_followup_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        contact_name TEXT,
        contact_company TEXT,
        product_name TEXT,
        manager_username TEXT
      )
    ''');

    // 5. Followups Cache
    await db.execute('''
      CREATE TABLE followups (
        id TEXT PRIMARY KEY,
        report_id TEXT,
        manager_id TEXT,
        notes TEXT,
        created_at TEXT,
        manager_username TEXT
      )
    ''');

    // 6. Notifications Cache
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        recipient_user_id TEXT,
        title TEXT,
        message TEXT,
        entity_type TEXT,
        entity_id TEXT,
        is_read INTEGER,
        created_at TEXT
      )
    ''');

    // 7. Sync Queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT, -- 'create_report', 'update_report', 'create_followup'
        payload TEXT, -- JSON encoded payload
        filepath TEXT, -- optional path to local attachment file
        created_at TEXT
      )
    ''');
  }

  // --- Sync Queue Helpers ---
  
  static Future<void> queueAction(String actionType, Map<String, dynamic> payload, {String? filepath}) async {
    final db = await database;
    await db.insert('sync_queue', {
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'filepath': filepath,
      'created_at': DateTime.now().toUtc().toIso8601String()
    });
  }

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  static Future<void> removeQueueItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
