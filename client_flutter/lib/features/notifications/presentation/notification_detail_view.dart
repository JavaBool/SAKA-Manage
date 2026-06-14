import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/notifications/models/notification_model.dart';
import 'package:client_flutter/features/reports/presentation/report_detail_view.dart';

class NotificationDetailView extends ConsumerStatefulWidget {
  final String notificationId;

  const NotificationDetailView({
    super.key,
    required this.notificationId,
  });

  @override
  ConsumerState<NotificationDetailView> createState() => _NotificationDetailViewState();
}

class _NotificationDetailViewState extends ConsumerState<NotificationDetailView> {
  NotificationModel? _notification;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotificationAndMarkRead();
  }

  Future<void> _loadNotificationAndMarkRead() async {
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final notif = await repo.getNotificationById(widget.notificationId);
      
      if (notif != null) {
        setState(() {
          _notification = notif;
          _isLoading = false;
        });
        
        // Mark as read in local cache and backend
        if (!notif.isRead) {
          await repo.markAsRead(widget.notificationId);
        }
      } else {
        setState(() {
          _errorMessage = "Notification details not found.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading notification details: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Notification Details"),
          backgroundColor: AppTheme.darkBg,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_errorMessage != null || _notification == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Notification Details"),
          backgroundColor: AppTheme.darkBg,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? "Notification not found",
                  style: const TextStyle(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final notif = _notification!;
    final isCritical = notif.title.contains("CRITICAL") || notif.message.contains("CRITICAL");
    final hasReport = notif.entityType == 'report' && notif.entityId != null && notif.entityId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Details"),
        backgroundColor: AppTheme.darkBg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme.darkCard,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCritical ? AppTheme.danger.withOpacity(0.3) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: isCritical 
                                ? AppTheme.danger.withOpacity(0.12) 
                                : AppTheme.primary.withOpacity(0.12),
                            radius: 24,
                            child: Icon(
                              isCritical ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
                              color: isCritical ? AppTheme.danger : AppTheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notif.createdAt.toLocal().toString().split('.').first,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32, color: AppTheme.borderColor),
                      const Text(
                        "Message Details",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notif.message,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppTheme.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (hasReport) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to the Report detail page
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ReportDetailView(reportId: notif.entityId!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text("View Related Report"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Back to Notifications"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
