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
import 'package:client_flutter/features/auth/models/user_model.dart';
import 'package:client_flutter/features/notifications/models/notification_model.dart';
import 'package:client_flutter/features/dashboard/presentation/dashboard_frame.dart';
import 'package:client_flutter/features/reports/presentation/report_detail_view.dart';
import 'package:client_flutter/features/notifications/presentation/notification_detail_view.dart';
import 'package:client_flutter/core/db_helper.dart';

class SystemNotificationService {
  final Ref ref;
  final FlutterLocalNotificationsPlugin _androidPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription? _sseSubscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  String? _currentUserToken;
  String? _currentUserId;
  final Set<String> _shownNotificationIds = {};

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
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("FCM foreground message received: ${message.messageId}");
        final notification = message.notification;
        if (notification != null) {
          final notifId = message.data['notification_id'];
          if (notifId != null) {
            if (_shownNotificationIds.contains(notifId)) {
              print("Notification $notifId already shown, discarding duplicate.");
              return;
            }
            _shownNotificationIds.add(notifId);
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

    // 3. Handle already cached user on startup
    // Wait for authStateProvider to load first
    Future.delayed(const Duration(seconds: 1), () async {
      final authState = ref.read(authStateProvider);
      final user = authState.value;
      if (user != null) {
        final token = await ref.read(apiClientProvider).storage.read(key: 'access_token');
        if (token != null) {
          startListening(user.id, token);
        }
      }
    });
  }

  void initAuthListener() {
    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) async {
      final user = next.value;
      if (user != null) {
        final token = await ref.read(apiClientProvider).storage.read(key: 'access_token');
        if (token != null) {
          startListening(user.id, token);
        }
      } else {
        stopListening();
      }
    });
  }

  void startListening(String userId, String token) {
    stopListening();
    
    _currentUserId = userId;
    _currentUserToken = token;
    _reconnectAttempts = 0;
    
    _connectToStream();
  }

  void stopListening() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    _currentUserId = null;
    _currentUserToken = null;
  }

  Future<void> _connectToStream() async {
    if (_currentUserId == null || _currentUserToken == null) return;
    
    _sseSubscription?.cancel();
    _sseSubscription = null;

    final String baseApiUrl = ref.read(apiClientProvider).dio.options.baseUrl;
    final String streamUrl = '$baseApiUrl/notifications/stream?user_id=$_currentUserId';

    try {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      client.connectionTimeout = const Duration(seconds: 15);
      
      final request = await client.getUrl(Uri.parse(streamUrl));
      request.headers.add('Authorization', 'Bearer $_currentUserToken');
      
      final response = await request.close();
      _isConnected = true;
      _reconnectAttempts = 0;

      print("SSE Stream connected successfully to $streamUrl");

      _sseSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          _handleStreamLine(line);
        },
        onError: (err) {
          print("SSE Stream error: $err");
          _handleDisconnect();
        },
        onDone: () {
          print("SSE Stream completed/disconnected.");
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("SSE Stream connection failed: $e");
      _handleDisconnect();
    }
  }

  void _handleStreamLine(String line) {
    if (line.trim().isEmpty) return;
    if (line.startsWith(':')) {
      // Heartbeat message
      return;
    }
    
    if (line.startsWith('data: ')) {
      final dataJson = line.substring(6).trim();
      try {
        final Map<String, dynamic> data = jsonDecode(dataJson);
        if (data.containsKey('status') && data['status'] == 'connected') {
          print("SSE Server acknowledged connection.");
          return;
        }
        
        final notif = NotificationModel.fromJson(data);
        
        // Check for duplicates
        if (_shownNotificationIds.contains(notif.id)) {
          print("Notification ${notif.id} already shown via FCM, discarding duplicate SSE event.");
          return;
        }
        _shownNotificationIds.add(notif.id);
        
        final payloadData = {
          'entity_type': notif.entityType,
          'entity_id': notif.entityId,
          'notification_id': notif.id,
        };
        
        showNativeNotification(notif.title, notif.message, data: payloadData);
        _syncNewNotification(notif);
      } catch (e) {
        print("Error parsing SSE stream notification data: $e | Line: $line");
      }
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
      
      ref.read(notificationsRepositoryProvider).getNotifications();
    } catch (e) {
      print("Error caching notification: $e");
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _sseSubscription?.cancel();
    _sseSubscription = null;

    if (_currentUserId == null) return; // Explicit stop

    _reconnectAttempts++;
    final backoffSeconds = (_reconnectAttempts * 2).clamp(2, 30);
    print("Reconnecting to SSE Stream in $backoffSeconds seconds... (Attempt $_reconnectAttempts)");
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      _connectToStream();
    });
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
  final service = SystemNotificationService(ref);
  service.initAuthListener();
  return service;
});
