// import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/features/reports/models/report_model.dart';
import 'package:client_flutter/features/reports/models/followup_model.dart';

class ReportsRepository {
  final ApiClient apiClient;
  final _uuid = const Uuid();

  ReportsRepository(this.apiClient);

  // Connectivity check helper
  Future<bool> _isOnline() async {
    try {
      final response = await apiClient.dio.get('/products', options: Options(
        receiveTimeout: const Duration(seconds: 2),
        connectTimeout: const Duration(seconds: 2),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<ReportModel>> getReports() async {
    try {
      final response = await apiClient.get('/reports');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final reports = data.map((json) => ReportModel.fromJson(json as Map<String, dynamic>)).toList();

        // Update local database cache
        final db = await DbHelper.database;
        await db.transaction((txn) async {
          await txn.delete('reports');
          for (var r in reports) {
            await txn.insert(
              'reports',
              r.toJson(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        return reports;
      }
    } catch (e) {
      print("Reports fetch error, loading from local cache: $e");
    }

    return await _getCachedReports();
  }

  Future<List<ReportModel>> _getCachedReports() async {
    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('reports', orderBy: 'created_at DESC');
    return maps.map((json) => ReportModel.fromJson(json)).toList();
  }

  Future<ReportModel> createReport({
    required String contactId,
    required String productId,
    required String feedbackType,
    required String summary,
    required String details,
    required String priority,
    required String status,
    DateTime? nextFollowupDate,
    String? localFilepath,
  }) async {
    final bool online = await _isOnline();
    
    final Map<String, dynamic> payload = {
      'contact_id': contactId,
      'product_id': productId,
      'feedback_type': feedbackType,
      'summary': summary,
      'details': details,
      'priority': priority,
      'status': status,
      'next_followup_date': nextFollowupDate?.toIso8601String(),
    };

    if (online) {
      try {
        FormData formData = FormData.fromMap({
          'contact_id': contactId,
          'product_id': productId,
          'feedback_type': feedbackType,
          'summary': summary,
          'details': details,
          'priority': priority,
          'status': status,
          'next_followup_date': nextFollowupDate?.toIso8601String(),
        });

        if (localFilepath != null && localFilepath.isNotEmpty) {
          final file = File(localFilepath);
          if (await file.exists()) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            formData.files.add(MapEntry(
              'attachments',
              await MultipartFile.fromFile(file.path, filename: fileName),
            ));
          }
        }

        final response = await apiClient.post('/reports', data: formData);
        if (response.statusCode == 201) {
          final createdReport = ReportModel.fromJson(response.data as Map<String, dynamic>);
          
          final db = await DbHelper.database;
          await db.insert(
            'reports',
            createdReport.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          return createdReport;
        }
      } catch (e) {
        print("Error submitting online, queueing offline: $e");
      }
    }

    // --- Offline Behavior ---
    final String tempId = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    
    final db = await DbHelper.database;
    final contactMaps = await db.query('contacts', where: 'id = ?', whereArgs: [contactId], limit: 1);
    final String contactName = contactMaps.isNotEmpty ? contactMaps.first['name'] as String : 'Contact Cache';
    final String? contactCompany = contactMaps.isNotEmpty ? contactMaps.first['company'] as String? : '';

    final productMaps = await db.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
    final String productName = productMaps.isNotEmpty ? productMaps.first['name'] as String : 'Product Cache';

    final offlineReport = ReportModel(
      id: tempId,
      contactId: contactId,
      managerId: 'offline-manager',
      productId: productId,
      feedbackType: feedbackType,
      summary: summary,
      details: details,
      priority: priority,
      status: status,
      nextFollowupDate: nextFollowupDate,
      createdAt: now,
      updatedAt: now,
      contactName: contactName,
      contactCompany: contactCompany,
      productName: productName,
      managerUsername: 'You (Offline)',
    );

    // Save report in local SQLite database
    await db.insert(
      'reports',
      offlineReport.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Add to local sync queue
    await DbHelper.queueAction('create_report', payload, filepath: localFilepath);
    print("Report queued offline. Temp ID: $tempId");

    return offlineReport;
  }

  Future<void> updateReport(ReportModel report) async {
    final bool online = await _isOnline();
    
    final Map<String, dynamic> payload = {
      'feedback_type': report.feedbackType,
      'summary': report.summary,
      'details': report.details,
      'priority': report.priority,
      'status': report.status,
      'next_followup_date': report.nextFollowupDate?.toIso8601String(),
    };

    final db = await DbHelper.database;
    
    // Update local cache immediately
    await db.update(
      'reports',
      report.toJson(),
      where: 'id = ?',
      whereArgs: [report.id],
    );

    if (online) {
      try {
        final response = await apiClient.put('/reports/${report.id}', data: payload);
        if (response.statusCode == 200) {
          final updatedReport = ReportModel.fromJson(response.data as Map<String, dynamic>);
          await db.update(
            'reports',
            updatedReport.toJson(),
            where: 'id = ?',
            whereArgs: [report.id],
          );
          return;
        }
      } catch (e) {
        print("Error editing online: $e");
      }
    }

    // Queue action if offline or API failed
    await DbHelper.queueAction('update_report', {
      'id': report.id,
      ...payload
    });
    print("Report edit queued offline.");
  }

  Future<FollowupModel> createFollowup(String reportId, String notes) async {
    final bool online = await _isOnline();
    final Map<String, dynamic> payload = {
      'report_id': reportId,
      'notes': notes,
    };
    
    final db = await DbHelper.database;
    
    // Offline followup mock
    final String tempId = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    final mockFollowup = FollowupModel(
      id: tempId,
      reportId: reportId,
      managerId: 'offline-manager',
      notes: notes,
      createdAt: now,
      managerUsername: 'You (Offline)',
    );

    // Save in local followup cache
    await db.insert('followups', mockFollowup.toJson());
    
    // Automatically update report status to followup_pending locally
    await db.rawUpdate(
      'UPDATE reports SET status = ? WHERE id = ?',
      ['followup_pending', reportId],
    );

    if (online) {
      try {
        final response = await apiClient.post('/followups', data: payload);
        if (response.statusCode == 201) {
          final createdFollowup = FollowupModel.fromJson(response.data as Map<String, dynamic>);
          await db.delete('followups', where: 'id = ?', whereArgs: [tempId]);
          await db.insert('followups', createdFollowup.toJson());
          return createdFollowup;
        }
      } catch (e) {
        print("Error logging followup online, queueing offline: $e");
      }
    }

    // Queue offline action
    await DbHelper.queueAction('create_followup', payload);
    return mockFollowup;
  }

  Future<List<FollowupModel>> getFollowups(String reportId) async {
    final bool online = await _isOnline();
    if (online) {
      try {
        final response = await apiClient.get('/followups', queryParameters: {'report_id': reportId});
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data as List;
          final followups = data.map((json) => FollowupModel.fromJson(json as Map<String, dynamic>)).toList();

          final db = await DbHelper.database;
          await db.delete('followups', where: 'report_id = ?', whereArgs: [reportId]);
          for (var f in followups) {
            await db.insert('followups', f.toJson());
          }
          return followups;
        }
      } catch (e) {
        print("Error getting followups, checking cache: $e");
      }
    }

    // Cache fallback
    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'followups',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'created_at ASC',
    );
    return maps.map((json) => FollowupModel.fromJson(json)).toList();
  }
}
