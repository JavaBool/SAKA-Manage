import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/router.dart';
import 'package:client_flutter/features/dashboard/presentation/dashboard_frame.dart';
import 'package:client_flutter/features/notifications/models/notification_model.dart';
import 'package:client_flutter/features/reports/presentation/report_detail_view.dart';
import 'package:client_flutter/features/notifications/presentation/notification_detail_view.dart';
import 'package:client_flutter/core/db_helper.dart';

class SystemNotificationService {
  final Ref ref;
  final FlutterLocalNotificationsPlugin _androidPlugin = FlutterLocalNotificationsPlugin();
  final Set<String> _shownMessageIds = {};

  SystemNotificationService(this.ref);

  void _handleNotificationTap(Map<String, dynamic> data) {
    print("Notification tapped with data: $data");
    
    final entityType = data['entity_type'] ?? '';
    final entityId = data['entity_id'] ?? '';
    final notificationId = data['notification_id'] ?? '';
    
    // Small delay to ensure navigator context and user model are loaded/ready
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        final user = ref.read(authStateProvider).value;
        if (user == null) {
          print("User is not logged in, ignoring notification tap navigation.");
          return;
        }
        
        final isBoss = user.role == 'BOSS';
        final context = rootNavigatorKey.currentContext;
        
        if (context != null) {
          if (entityType == 'report' && entityId.isNotEmpty) {
            // Switch to Reports tab (Index 2 for both Boss and Manager)
            ref.read(activeMenuIndexProvider.notifier).state = 2;
            
            // Push Report Detail page on root navigator
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReportDetailView(reportId: entityId),
              ),
            );
          } else if (notificationId.isNotEmpty) {
            // Switch to Notifications Center tab (Index 6 for Boss, Index 3 for Manager)
            ref.read(activeMenuIndexProvider.notifier).state = isBoss ? 6 : 3;
            
            // Push Notification Detail page on root navigator
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NotificationDetailView(notificationId: notificationId),
              ),
            );
          } else {
            // Default to Notifications Center tab (Index 6 for Boss, Index 3 for Manager)
            ref.read(activeMenuIndexProvider.notifier).state = isBoss ? 6 : 3;
          }
        }
      } catch (e) {
        print("Error handling notification tap navigation: $e");
      }
    });
  }

  Future<void> initialize() async {
    // 1. Initialize Android notifications
    if (Platform.isAndroid) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _androidPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          final payloadStr = details.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(payloadStr);
              _handleNotificationTap(data);
            } catch (e) {
              print("Error parsing local notification tap payload: $e");
            }
          }
        },
      );

      // Create high importance channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'saka_manage_push',
        'SAKA-Manage Real-time Push',
        description: 'This channel is used for real-time customer feedback push alerts.',
        importance: Importance.max,
        playSound: true,
      );

      await _androidPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Request runtime notification permission (Android 13+)
      await _androidPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Configure Foreground FCM Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        print("FCM foreground message received: ${message.messageId}");
        final notification = message.notification;
        if (notification != null) {
          final msgId = message.messageId;
          if (msgId != null) {
            if (_shownMessageIds.contains(msgId)) {
              print("FCM message $msgId already processed, ignoring.");
              return;
            }
            _shownMessageIds.add(msgId);
          }
          
          final notifId = message.data['notification_id'] ?? '';
          
          // Reconstruct and cache NotificationModel if we have notification_id
          if (notifId.isNotEmpty) {
            final notif = NotificationModel(
              id: notifId,
              recipientUserId: '', // Ignored locally, populated from sync
              title: notification.title ?? '',
              message: notification.body ?? '',
              entityType: message.data['entity_type'],
              entityId: message.data['entity_id'],
              isRead: false,
              createdAt: DateTime.now(),
            );
            await _syncNewNotification(notif);
          } else {
            // Fallback: trigger API pull to sync notifications list
            ref.read(notificationsRepositoryProvider).getNotifications();
          }

          showNativeNotification(
            notification.title ?? '',
            notification.body ?? '',
            data: message.data,
          );
        }
      });

      // Configure Background FCM Opened App Listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("FCM notification opened app from background: ${message.messageId}");
        _handleNotificationTap(message.data);
      });

      // Check Terminated FCM Opened App Initial Message
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print("FCM app launched from terminated state via notification: ${message.messageId}");
          _handleNotificationTap(message.data);
        }
      });
    }

    // 2. Initialize Windows local notifier
    if (Platform.isWindows) {
      await localNotifier.setup(
        appName: 'SAKA-Manage',
      );
    }
  }

  Future<void> _syncNewNotification(NotificationModel notif) async {
    try {
      final db = await DbHelper.database;
      await db.insert(
        'notifications',
        notif.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Refresh Riverpod provider so UI gets updated in real-time
      ref.read(notificationsRepositoryProvider).getNotifications();
    } catch (e) {
      print("Error caching notification: $e");
    }
  }

  Future<void> showNativeNotification(String title, String message, {Map<String, dynamic>? data}) async {
    if (Platform.isAndroid) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'saka_manage_push',
        'SAKA-Manage Real-time Push',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await _androidPlugin.show(
        DateTime.now().millisecond,
        title,
        message,
        platformChannelSpecifics,
        payload: data != null ? jsonEncode(data) : null,
      );
    }

    if (Platform.isWindows) {
      LocalNotification notification = LocalNotification(
        title: title,
        body: message,
      );
      await notification.show();
    }
  }
}

final systemNotificationServiceProvider = Provider<SystemNotificationService>((ref) {
  return SystemNotificationService(ref);
});
