import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:client_flutter/firebase_options.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/core/router.dart';
import 'package:client_flutter/core/theme.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

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

  // Run the app inside a ProviderScope for Riverpod
  runApp(
    const ProviderScope(
      child: SAKAManageApp(),
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
