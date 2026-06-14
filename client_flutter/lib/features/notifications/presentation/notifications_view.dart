import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/notifications/models/notification_model.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  late Future<List<NotificationModel>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  void _refreshNotifications() {
    setState(() {
      _notificationsFuture = ref.read(notificationsRepositoryProvider).getNotifications();
    });
  }

  Future<void> _markRead(String id) async {
    await ref.read(notificationsRepositoryProvider).markAsRead(id);
    _refreshNotifications();
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllAsRead();
    _refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Notifications Center", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text("Alerts regarding report submissions, followups, and escalations.", style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text("Mark All Read"),
                    onPressed: _markAllRead,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.primary),
                    onPressed: _refreshNotifications,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<NotificationModel>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error fetching notifications: ${snapshot.error}", style: const TextStyle(color: AppTheme.danger)),
                  );
                }
                
                final notifications = snapshot.data ?? [];
                
                if (notifications.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, color: AppTheme.textMuted, size: 48),
                        SizedBox(height: 16),
                        Text("No notifications found.", style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isCritical = n.title.contains("CRITICAL") || n.message.contains("CRITICAL");
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: n.isRead ? AppTheme.darkCard : AppTheme.darkCard.withBlue(40).withRed(20),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCritical 
                              ? AppTheme.danger.withOpacity(0.12) 
                              : (n.isRead ? AppTheme.textMuted.withOpacity(0.12) : AppTheme.primary.withOpacity(0.12)),
                          child: Icon(
                            isCritical 
                                ? Icons.warning_amber_rounded 
                                : (n.isRead ? Icons.notifications_none : Icons.notifications_active),
                            color: isCritical 
                                ? AppTheme.danger 
                                : (n.isRead ? AppTheme.textMuted : AppTheme.primary),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: n.isRead ? FontWeight.bold : FontWeight.w900,
                                  color: n.isRead ? AppTheme.textMain : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              n.message,
                              style: TextStyle(
                                color: n.isRead ? AppTheme.textMuted : AppTheme.textMain,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              n.createdAt.toLocal().toString().split('.').first,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        trailing: !n.isRead
                            ? IconButton(
                                icon: const Icon(Icons.done, color: AppTheme.success, size: 20),
                                tooltip: "Mark as read",
                                onPressed: () => _markRead(n.id),
                              )
                            : null,
                        onTap: !n.isRead ? () => _markRead(n.id) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
