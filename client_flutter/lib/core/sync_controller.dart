import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';

class SyncController {
  final ApiClient apiClient;
  bool _isSyncing = false;

  SyncController(this.apiClient) {
    // Listen to network change events
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        syncNow();
      }
    });
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    print("Background sync started...");

    try {
      final queue = await DbHelper.getQueue();
      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (var item in queue) {
        final int queueId = item['id'] as int;
        final String actionType = item['action_type'] as String;
        final String payloadStr = item['payload'] as String;
        final String? filepath = item['filepath'] as String?;
        
        final Map<String, dynamic> payload = jsonDecode(payloadStr);
        bool success = false;

        try {
          if (actionType == 'create_report') {
            FormData formData = FormData.fromMap({
              'contact_id': payload['contact_id'],
              'product_id': payload['product_id'],
              'feedback_type': payload['feedback_type'],
              'summary': payload['summary'],
              'details': payload['details'],
              'priority': payload['priority'],
              'status': payload['status'],
              'next_followup_date': payload['next_followup_date'],
            });

            // If an attachment file path is stored
            if (filepath != null && filepath.isNotEmpty) {
              final file = File(filepath);
              if (await file.exists()) {
                final String fileName = file.path.split(Platform.pathSeparator).last;
                formData.files.add(MapEntry(
                  'attachments',
                  await MultipartFile.fromFile(file.path, filename: fileName),
                ));
              }
            }

            final response = await apiClient.post('/reports', data: formData);
            if (response.statusCode == 201) {
              success = true;
            }
          } else if (actionType == 'create_followup') {
            final response = await apiClient.post('/followups', data: {
              'report_id': payload['report_id'],
              'notes': payload['notes'],
            });
            if (response.statusCode == 201) {
              success = true;
            }
          }

          if (success) {
            // Delete queued item upon successful API delivery
            await DbHelper.removeQueueItem(queueId);
            print("Successfully synced queued item $queueId ($actionType)");
          }
        } on DioException catch (dioErr) {
          // If server returns validation/business error (e.g. 400 or 403),
          // discard from queue to prevent queue clogging (conflict resolution / last write wins)
          if (dioErr.response != null && 
              (dioErr.response!.statusCode! >= 400 && dioErr.response!.statusCode! < 500)) {
            print("Sync failed with client error (${dioErr.response!.statusCode!}). Dropping item $queueId.");
            await DbHelper.removeQueueItem(queueId);
          } else {
            // Server down or network timeout, retry on next connection
            print("Sync failed with network error. Will retry later. Error: $dioErr");
            break; 
          }
        } catch (e) {
          // General parsing exception
          print("General exception during sync: $e. Dropping item $queueId.");
          await DbHelper.removeQueueItem(queueId);
        }
      }
    } catch (e) {
      print("Error during sync queue execution: $e");
    } finally {
      _isSyncing = false;
      print("Background sync ended.");
    }
  }
}
