import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';

class BossAuditLogsView extends ConsumerStatefulWidget {
  const BossAuditLogsView({super.key});

  @override
  ConsumerState<BossAuditLogsView> createState() => _BossAuditLogsViewState();
}

class _BossAuditLogsViewState extends ConsumerState<BossAuditLogsView> {
  late Future<List<dynamic>> _auditLogsFuture;

  @override
  void initState() {
    super.initState();
    _refreshAuditLogs();
  }

  void _refreshAuditLogs() {
    setState(() {
      _auditLogsFuture = _fetchAuditLogs();
    });
  }

  Future<List<dynamic>> _fetchAuditLogs() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/audit_logs');
    return response.data as List;
  }

  void _showDiffDialog(BuildContext context, Map<String, dynamic> log) {
    String prettyOld = "";
    String prettyNew = "";
    
    try {
      if (log['old_value_json'] != null) {
        final parsed = jsonDecode(log['old_value_json']);
        prettyOld = const JsonEncoder.withIndent('  ').convert(parsed);
      }
    } catch (_) {
      prettyOld = log['old_value_json'] ?? '';
    }

    try {
      if (log['new_value_json'] != null) {
        final parsed = jsonDecode(log['new_value_json']);
        prettyNew = const JsonEncoder.withIndent('  ').convert(parsed);
      }
    } catch (_) {
      prettyNew = log['new_value_json'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: Row(
            children: [
              const Icon(Icons.compare_arrows, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Audit Log Details (${log['action']})",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 800,
            height: 500,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("OLD VALUE", style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              prettyOld.isEmpty ? "No old values recorded (Creation or System action)" : prettyOld,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NEW VALUE", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              prettyNew.isEmpty ? "No new values recorded (Delete or Session action)" : prettyNew,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.textMain),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: AppTheme.primary)),
            )
          ],
        );
      },
    );
  }

  IconData _getActionIcon(String action) {
    final act = action.toLowerCase();
    if (act.contains('login')) return Icons.login;
    if (act.contains('logout')) return Icons.logout;
    if (act.contains('create')) return Icons.add_circle_outline;
    if (act.contains('update')) return Icons.edit_outlined;
    if (act.contains('delete')) return Icons.delete_outline;
    return Icons.settings_backup_restore;
  }

  Color _getActionColor(String action) {
    final act = action.toLowerCase();
    if (act.contains('create')) return AppTheme.success;
    if (act.contains('update')) return AppTheme.primary;
    if (act.contains('delete')) return AppTheme.danger;
    if (act.contains('login') || act.contains('logout')) return AppTheme.secondary;
    return AppTheme.textMuted;
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
                  Text("System Audit Trail", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text("Immutable history of user actions and database transactions.", style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primary),
                onPressed: _refreshAuditLogs,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _auditLogsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error fetching audit logs: ${snapshot.error}", style: const TextStyle(color: AppTheme.danger)),
                  );
                }
                
                final logs = snapshot.data ?? [];
                
                if (logs.isEmpty) {
                  return const Center(
                    child: Text("No audit records found.", style: TextStyle(color: AppTheme.textMuted)),
                  );
                }

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final String rawUserId = log['user_id'] ?? '';
                    final bool isAdmin = rawUserId == '00000000-0000-0000-0000-000000000000';
                    final String userDisplay = isAdmin 
                        ? 'Administrator' 
                        : (log['user_username'] ?? 'System / Anonymous (${rawUserId.substring(0, 8)})');
                    final String timestamp = log['created_at'] != null
                        ? DateTime.parse(log['created_at']).toLocal().toString().split('.').first
                        : '';
                    
                    final String action = log['action'] ?? 'Action';
                    final IconData icon = _getActionIcon(action);
                    final Color color = _getActionColor(action);
                    final bool hasPayload = log['old_value_json'] != null || log['new_value_json'] != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.12),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              action,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            if (log['entity_type'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (log['entity_type'] as String).toUpperCase(),
                                  style: const TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              )
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 13, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(userDisplay, style: const TextStyle(color: AppTheme.textMain, fontSize: 12)),
                                const SizedBox(width: 16),
                                const Icon(Icons.network_ping_outlined, size: 13, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(log['ip_address'] ?? '127.0.0.1', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(timestamp, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                        trailing: hasPayload
                            ? TextButton.icon(
                                icon: const Icon(Icons.code, size: 16, color: AppTheme.primary),
                                label: const Text("Payload", style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                                onPressed: () => _showDiffDialog(context, log),
                              )
                            : null,
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
