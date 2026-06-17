import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/system_notification_service.dart';

class WindowsNotificationPoller {
  final Ref ref;
  Timer? _timer;
  Set<String> _knownIds = {};
  bool _isInitialized = false;

  WindowsNotificationPoller(this.ref);

  Future<void> start() async {
    if (!Platform.isWindows) return;
    if (_timer != null) return; // Already running

    print("[WindowsNotificationPoller] Starting Windows background poller...");
    
    try {
      // 1. Fetch current cached notification IDs to avoid toast spam of historic notifications
      final repo = ref.read(notificationsRepositoryProvider);
      final cached = await repo.getCachedNotifications();
      _knownIds = cached.map((n) => n.id).toSet();
      _isInitialized = true;
      print("[WindowsNotificationPoller] Initialized in-memory cache with ${_knownIds.length} historic notification IDs.");
    } catch (e) {
      print("[WindowsNotificationPoller] Error pre-populating notification cache: $e");
    }

    // 2. Start periodic 10-second polling
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _pollNotifications());
  }

  void stop() {
    if (_timer != null) {
      print("[WindowsNotificationPoller] Stopping Windows background poller...");
      _timer!.cancel();
      _timer = null;
    }
    _knownIds.clear();
    _isInitialized = false;
  }

  Future<void> _pollNotifications() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      // User logged out, stop polling
      stop();
      return;
    }

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final latest = await repo.getNotifications();
      
      if (!_isInitialized) {
        // Fallback initialization if startup fetch failed
        _knownIds = latest.map((n) => n.id).toSet();
        _isInitialized = true;
        return;
      }

      for (var n in latest) {
        if (!_knownIds.contains(n.id)) {
          _knownIds.add(n.id);
          
          if (!n.isRead) {
            print("[WindowsNotificationPoller] New unread notification detected: ${n.title}");
            final systemNotifService = ref.read(systemNotificationServiceProvider);
            
            final Map<String, dynamic> data = {
              'notification_id': n.id,
              'entity_type': n.entityType,
              'entity_id': n.entityId,
            };

            await systemNotifService.showNativeNotification(
              n.title,
              n.message,
              data: data,
            );
          }
        }
      }
    } catch (e) {
      print("[WindowsNotificationPoller] Error during background poll: $e");
    }
  }
}

final windowsNotificationPollerProvider = Provider<WindowsNotificationPoller>((ref) {
  return WindowsNotificationPoller(ref);
});
