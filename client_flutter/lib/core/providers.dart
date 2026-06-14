import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/features/auth/models/user_model.dart';
import 'package:client_flutter/features/auth/repository/auth_repository.dart';
import 'package:client_flutter/features/contacts/repository/contacts_repository.dart';
import 'package:client_flutter/features/products/repository/products_repository.dart';
import 'package:client_flutter/features/reports/repository/reports_repository.dart';
import 'package:client_flutter/features/notifications/repository/notifications_repository.dart';
import 'package:client_flutter/core/sync_controller.dart';

// Core Providers
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final storageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

// Sync Controller
final syncControllerProvider = Provider<SyncController>((ref) {
  return SyncController(ref.watch(apiClientProvider));
});

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(apiClientProvider));
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(apiClientProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AsyncValue.data(null)) {
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.getCachedUser();
      state = AsyncValue.data(user);
      if (user != null) {
        _registerFCMToken();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.login(username, password);
      state = AsyncValue.data(user);
      if (user != null) {
        _registerFCMToken();
      }
      return user != null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.logout();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _registerFCMToken() async {
    try {
      if (Platform.isAndroid) {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final token = await messaging.getToken();
        if (token != null) {
          print("FCM Token: $token");
          await _authRepository.registerDeviceToken(token, 'android');
        }
      } else if (Platform.isWindows) {
        print("FCM is skipped on native Windows desktop.");
      }
    } catch (e) {
      print("Error registering FCM token: $e");
    }
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
