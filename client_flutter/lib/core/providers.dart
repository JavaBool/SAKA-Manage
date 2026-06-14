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
import 'package:client_flutter/features/analytics/repository/analytics_repository.dart';
import 'package:client_flutter/core/sync_controller.dart';

// Core Providers
final backendUrlProvider = StateNotifierProvider<BackendUrlNotifier, String>((ref) {
  return BackendUrlNotifier(ref.watch(storageProvider));
});

class BackendUrlNotifier extends StateNotifier<String> {
  final FlutterSecureStorage _storage;
  static const String key = 'selected_backend_url';

  static const String huggingFaceUrl = 'https://javabool-sakamanage.hf.space/api/v1';
  static const String renderUrl = 'https://saka-manage.onrender.com/api/v1';
  static const String vercelUrl = 'https://saka-manage.vercel.app/api/v1';

  BackendUrlNotifier(this._storage) : super(huggingFaceUrl) {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final saved = await _storage.read(key: key);
    if (saved != null && (saved == renderUrl || saved == huggingFaceUrl || saved == vercelUrl)) {
      state = saved;
    }
  }

  Future<void> setUrl(String url) async {
    await _storage.write(key: key, value: url);
    state = url;
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final activeUrl = ref.watch(backendUrlProvider);
  final client = ApiClient(baseUrl: activeUrl);
  client.onUnauthorized = () {
    ref.read(authStateProvider.notifier).logout();
  };
  return client;
});
final storageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

// Sync Controller
final syncControllerProvider = Provider<SyncController>((ref) {
  return SyncController(ref.watch(apiClientProvider));
});

// Repositories
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final Provider<ContactsRepository> contactsRepositoryProvider = Provider<ContactsRepository>((Ref ref) {
  return ContactsRepository(ref.watch(apiClientProvider));
});

final Provider<ProductsRepository> productsRepositoryProvider = Provider<ProductsRepository>((Ref ref) {
  return ProductsRepository(ref.watch(apiClientProvider));
});

final Provider<ReportsRepository> reportsRepositoryProvider = Provider<ReportsRepository>((Ref ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

final Provider<NotificationsRepository> notificationsRepositoryProvider = Provider<NotificationsRepository>((Ref ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

final Provider<AnalyticsRepository> analyticsRepositoryProvider = Provider<AnalyticsRepository>((Ref ref) {
  return AnalyticsRepository(ref.watch(apiClientProvider));
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
