import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/features/auth/models/user_model.dart';
import 'package:client_flutter/features/notifications/models/notification_model.dart';
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

  SystemNotificationService(this.ref);

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
        showNativeNotification(notif.title, notif.message);
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

  Future<void> showNativeNotification(String title, String message) async {
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
