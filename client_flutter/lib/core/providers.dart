import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';
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
  client.onUnauthorized = (reason, details) {
    ref.read(authStateProvider.notifier).logout(reason: reason, details: details);
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

  Map<String, dynamic> _getJwtMetadata(String? token) {
    if (token == null) return {};
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64.normalize(payload);
        final decoded = utf8.decode(base64.decode(normalized));
        final map = json.decode(decoded) as Map<String, dynamic>;
        final expVal = map['exp'];
        if (expVal is int) {
          final expTime = DateTime.fromMillisecondsSinceEpoch(expVal * 1000).toUtc();
          return {
            'jwt_exp': expTime.toIso8601String(),
          };
        }
      }
    } catch (_) {}
    return {};
  }

  void _logJwtDiagnostics(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print("[AUTH_DEBUG] JWT decode error: Invalid JWT format (parts count = ${parts.length})");
        return;
      }
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final map = json.decode(decoded) as Map<String, dynamic>;
      
      final iatVal = map['iat'];
      final expVal = map['exp'];
      
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      DateTime? iatTime;
      DateTime? expTime;
      if (iatVal is int) {
        iatTime = DateTime.fromMillisecondsSinceEpoch(iatVal * 1000);
      }
      if (expVal is int) {
        expTime = DateTime.fromMillisecondsSinceEpoch(expVal * 1000);
      }
      
      final remainingSeconds = (expVal is int) ? (expVal - nowSeconds) : 0;
      
      print("[AUTH_DEBUG]\nJWT Expiration Diagnostics:");
      print(" - Issued At (iat): $iatVal (${iatTime?.toUtc().toIso8601String()})");
      print(" - Expires At (exp): $expVal (${expTime?.toUtc().toIso8601String()})");
      print(" - Current Time: $nowSeconds (${DateTime.now().toUtc().toIso8601String()})");
      print(" - Remaining Lifetime: ${remainingSeconds}s");
    } catch (e) {
      print("[AUTH_DEBUG] JWT decode error: $e");
    }
  }

  Future<void> _loadCachedUser() async {
    state = const AsyncValue.loading();
    String? token;
    String? userId;
    bool storageReadSuccess = false;
    
    try {
      token = await _authRepository.storage.read(key: 'access_token');
      userId = await _authRepository.storage.read(key: 'user_id');
      storageReadSuccess = true;
    } catch (e) {
      print("[AUTH_DEBUG] Storage read failure during startup: $e");
      final errorDetails = {
        'error': e.toString(),
        'action': 'startup_read',
        'current_time': DateTime.now().toUtc().toIso8601String(),
        'token_exists': false,
        'user_id_exists': false,
        'cached_user_exists': false,
      };
      await logout(reason: 'storage_read_failure', details: errorDetails);
      state = const AsyncValue.data(null);
      return;
    }

    print("[AUTH_DEBUG]\nStartup authentication check:");
    print(" - Secure storage read success: $storageReadSuccess");
    print(" - access_token exists: ${token != null}");
    print(" - user_id exists: ${userId != null}");

    if (token != null) {
      _logJwtDiagnostics(token);
    }

    if (token == null || userId == null) {
      print("[AUTH_DEBUG] Missing secure storage token on startup.");
      final details = {
        'access_token_exists': token != null,
        'user_id_exists': userId != null,
        'storage_read_success': storageReadSuccess,
        'current_time': DateTime.now().toUtc().toIso8601String(),
        if (userId != null) 'user_id': userId,
        ..._getJwtMetadata(token),
        'token_exists': token != null,
        'cached_user_exists': false,
      };
      await logout(reason: 'missing_secure_storage_token', details: details);
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final user = await _authRepository.getCachedUser();
      print(" - Cached user exists: ${user != null}");
      
      if (user == null) {
        print("[AUTH_DEBUG] Startup session restoration failure: user token exists but profile missing in SQLite cache.");
        final details = {
          'user_id': userId,
          'token': token,
          'current_time': DateTime.now().toUtc().toIso8601String(),
          ..._getJwtMetadata(token),
          'token_exists': true,
          'user_id_exists': true,
          'cached_user_exists': false,
        };
        await logout(reason: 'startup_session_restoration_failure', details: details);
        state = const AsyncValue.data(null);
      } else if (!user.active) {
        print("[AUTH_DEBUG] User is deactivated locally.");
        final details = {
          'user_id': user.id,
          'username': user.username,
          'current_time': DateTime.now().toUtc().toIso8601String(),
          ..._getJwtMetadata(token),
          'token_exists': true,
          'user_id_exists': true,
          'cached_user_exists': true,
        };
        await logout(reason: 'user_deactivated', details: details);
        state = const AsyncValue.data(null);
      } else {
        await DbHelper.logAuthEvent('startup_session_restoration', {
          'user_id': user.id,
          'username': user.username,
          'current_time': DateTime.now().toUtc().toIso8601String(),
          ..._getJwtMetadata(token),
          'token_exists': true,
          'user_id_exists': true,
          'cached_user_exists': true,
        });

        state = AsyncValue.data(user);
        _registerFCMToken();
      }
    } catch (e, st) {
      print("[AUTH_DEBUG] Unexpected exception during startup: $e");
      final details = {
        'error': e.toString(),
        if (userId != null) 'user_id': userId,
        'current_time': DateTime.now().toUtc().toIso8601String(),
        ..._getJwtMetadata(token),
        'token_exists': token != null,
        'user_id_exists': userId != null,
        'cached_user_exists': false,
      };
      await logout(reason: 'unexpected_exception', details: details);
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.login(username, password);
      state = AsyncValue.data(user);
      if (user != null) {
        final token = await _authRepository.storage.read(key: 'access_token');
        await DbHelper.logAuthEvent('login_success', {
          'user_id': user.id,
          'username': user.username,
          'role': user.role,
          'current_time': DateTime.now().toUtc().toIso8601String(),
          ..._getJwtMetadata(token),
        });
        _registerFCMToken();
      }
      return user != null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout({String reason = 'manual_logout', Map<String, dynamic>? details}) async {
    print("[AUTH_DEBUG]\nLogout triggered\nReason: $reason");

    // Read current session info to enrich logs before clearing them
    String? userId;
    String? token;
    try {
      userId = await _authRepository.storage.read(key: 'user_id');
      token = await _authRepository.storage.read(key: 'access_token');
    } catch (_) {}

    final Map<String, dynamic> enrichedDetails = {
      'current_time': DateTime.now().toUtc().toIso8601String(),
      if (userId != null) 'user_id': userId,
      ..._getJwtMetadata(token),
      ...?details,
    };
    
    // Log the specific trigger event if not manual
    if (reason != 'manual_logout') {
      await DbHelper.logAuthEvent(reason, enrichedDetails);
    }

    // Log the final logout event itself
    final Map<String, dynamic> logoutDetails = {
      'logout_reason': reason,
      ...enrichedDetails,
    };
    await DbHelper.logAuthEvent('logout', logoutDetails);

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
      final storage = _authRepository.storage;
      String? deviceId = await storage.read(key: 'device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await storage.write(key: 'device_id', value: deviceId);
      }

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
          await _authRepository.registerDeviceToken(token, 'android', deviceId);
        }
      } else if (Platform.isWindows) {
        print("FCM is skipped on native Windows desktop. Device ID: $deviceId");
      }
    } catch (e) {
      print("Error registering FCM token: $e");
    }
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// Developer Mode Persistent Settings Provider
final developerModeProvider = StateNotifierProvider<DeveloperModeNotifier, bool>((ref) {
  return DeveloperModeNotifier(ref.watch(storageProvider));
});

class DeveloperModeNotifier extends StateNotifier<bool> {
  final FlutterSecureStorage _storage;
  static const String key = 'developer_mode_enabled';

  DeveloperModeNotifier(this._storage) : super(false) {
    _load();
  }

  Future<void> _load() async {
    final val = await _storage.read(key: key);
    state = val == 'true';
  }

  Future<void> toggle(bool enabled) async {
    await _storage.write(key: key, value: enabled.toString());
    state = enabled;
  }
}

// Dynamic menu items provider
final menuItemsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final userVal = ref.watch(authStateProvider).value;
  if (userVal == null) return [];

  final bool isBoss = userVal.role == 'BOSS';
  final bool isDevMode = ref.watch(developerModeProvider);

  final List<Map<String, dynamic>> menuItems = [];
  menuItems.add({'title': 'Dashboard', 'icon': isBoss ? Icons.analytics_outlined : Icons.assessment_outlined});
  menuItems.add({'title': 'Contacts', 'icon': isBoss ? Icons.contact_phone_outlined : Icons.contact_mail_outlined});
  menuItems.add({'title': 'Reports', 'icon': isBoss ? Icons.description_outlined : Icons.rate_review_outlined});

  if (isBoss) {
    menuItems.add({'title': 'Products', 'icon': Icons.shopping_bag_outlined});
    menuItems.add({'title': 'Personnel', 'icon': Icons.badge_outlined});
    if (isDevMode) {
      menuItems.add({'title': 'Audit Logs', 'icon': Icons.fingerprint_outlined});
    }
  }

  menuItems.add({'title': 'Notifications', 'icon': Icons.notifications_none_outlined});
  menuItems.add({'title': 'Daily Targets', 'icon': Icons.track_changes_outlined});

  if (isDevMode) {
    menuItems.add({'title': 'Auth Diagnostics', 'icon': Icons.security_outlined});
  }

  return menuItems;
});
