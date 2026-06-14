import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:client_flutter/firebase_options.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/core/router.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/core/system_notification_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager on desktop
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true); // Prevent direct exit on close
    });
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully.");
  } catch (e) {
    print("Failed to initialize Firebase: $e");
  }

  // Pre-initialize database schema
  try {
    await DbHelper.database;
    print("SQLite Database initialized successfully.");
  } catch (e) {
    print("Failed to initialize SQLite database: $e");
  }

  // Set up Riverpod Container and initialize notifications
  final container = ProviderContainer();
  try {
    await container.read(systemNotificationServiceProvider).initialize();
    print("System Notification Service initialized successfully.");
  } catch (e) {
    print("Failed to initialize system notification service: $e");
  }

  // Run the app using UncontrolledProviderScope for Riverpod container reuse
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SAKAManageApp(),
    ),
  );
}

class SAKAManageApp extends StatelessWidget {
  const SAKAManageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SAKA Manage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
