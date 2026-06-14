import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:client_flutter/features/auth/presentation/login_screen.dart';
import 'package:client_flutter/features/dashboard/presentation/dashboard_frame.dart';
import 'package:client_flutter/features/auth/repository/auth_repository.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  redirect: (BuildContext context, GoRouterState state) async {
    String? token = AuthRepository.token;
    if (token == null) {
      const storage = FlutterSecureStorage();
      token = await storage.read(key: 'access_token');
      if (token != null) {
        AuthRepository.token = token;
      }
    }
    final loggingIn = state.matchedLocation == '/login';
    
    if (token == null) {
      // Force redirect to login if unauthenticated
      return loggingIn ? null : '/login';
    }
    
    if (loggingIn) {
      // Redirect to main workspace if already logged in
      return '/';
    }
    
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const DashboardFrame();
      },
    ),
  ],
);
