import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/auth/models/user_model.dart';
import 'package:client_flutter/core/server_switcher.dart';

// Views
import 'package:client_flutter/features/contacts/presentation/contacts_view.dart';
import 'package:client_flutter/features/reports/presentation/reports_view.dart';
import 'package:client_flutter/features/notifications/presentation/notifications_view.dart';
import 'package:client_flutter/features/dashboard/presentation/boss_analytics_view.dart';
import 'package:client_flutter/features/dashboard/presentation/boss_audit_logs_view.dart';
import 'package:client_flutter/features/products/presentation/products_view.dart';
import 'package:client_flutter/features/analytics/presentation/daily_targets_view.dart';
import 'package:client_flutter/features/dashboard/presentation/auth_diagnostics_view.dart';

// Local view manager state provider
final activeMenuIndexProvider = StateProvider<int>((ref) => 0);

class DashboardFrame extends ConsumerStatefulWidget {
  const DashboardFrame({super.key});

  @override
  ConsumerState<DashboardFrame> createState() => _DashboardFrameState();
}

class _DashboardFrameState extends ConsumerState<DashboardFrame> with WindowListener, TrayListener {

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initSystemTray();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    try {
      await trayManager.setIcon('app_icon');
      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Open SAKA-Manage',
          ),
          MenuItem(
            key: 'exit_app',
            label: 'Exit Application',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
      print("System tray initialized successfully.");
    } catch (e) {
      print("Error initializing system tray: $e");
    }
  }

  @override
  void onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      _handleWindowClose();
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.destroy();
    }
  }

  Future<void> _handleWindowClose() async {
    final storage = ref.read(apiClientProvider).storage;
    final behavior = await storage.read(key: 'close_behavior');

    if (behavior == 'exit') {
      await windowManager.destroy();
      return;
    } else if (behavior == 'minimize') {
      await windowManager.hide();
      return;
    }

    if (!mounted) return;
    
    bool rememberChoice = false;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: const Text("SAKA-Manage Exit Options", style: TextStyle(color: AppTheme.textMain)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Do you want to close SAKA-Manage or minimize it to the system tray?",
                    style: TextStyle(color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Minimizing to the tray keeps the app running in the background so you can continue receiving real-time notifications.",
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        activeColor: AppTheme.primary,
                        value: rememberChoice,
                        onChanged: (val) {
                          setDialogState(() {
                            rememberChoice = val ?? false;
                          });
                        },
                      ),
                      const Text("Remember my choice", style: TextStyle(fontSize: 13, color: AppTheme.textMain)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text("CANCEL", style: TextStyle(color: AppTheme.textMuted)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'exit'),
                  child: const Text("EXIT", style: TextStyle(color: AppTheme.danger)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'minimize'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("MINIMIZE TO TRAY"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'exit') {
      if (rememberChoice) {
        await storage.write(key: 'close_behavior', value: 'exit');
      }
      await windowManager.destroy();
    } else if (result == 'minimize') {
      if (rememberChoice) {
        await storage.write(key: 'close_behavior', value: 'minimize');
      }
      await windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
      if (next is AsyncData<UserModel?> && next.value == null) {
        context.go('/login');
      }
    });

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (UserModel? user) {
        if (user == null) {
          // Double check redirect
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Run sync in background on load
        ref.read(syncControllerProvider).syncNow();

        final int activeIndex = ref.watch(activeMenuIndexProvider);
        final bool isBoss = user.role == 'BOSS';
        final menuItems = ref.watch(menuItemsProvider);
        final bool isDevMode = ref.watch(developerModeProvider);

        if (activeIndex >= menuItems.length) {
          Future.microtask(() {
            ref.read(activeMenuIndexProvider.notifier).state = 0;
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final itemTitle = menuItems[activeIndex]['title'] as String;
        Widget activeView = const SizedBox();
        switch (itemTitle) {
          case 'Dashboard':
            activeView = isBoss ? const BossAnalyticsView() : const ManagerSummaryView();
            break;
          case 'Contacts':
            activeView = const ContactsView();
            break;
          case 'Reports':
            activeView = const ReportsView();
            break;
          case 'Products':
            activeView = const ProductsView();
            break;
          case 'Personnel':
            activeView = const ManagersListView();
            break;
          case 'Audit Logs':
            activeView = const BossAuditLogsView();
            break;
          case 'Notifications':
            activeView = const NotificationsView();
            break;
          case 'Daily Targets':
            activeView = const DailyTargetsView();
            break;
          case 'Auth Diagnostics':
            activeView = const AuthDiagnosticsView();
            break;
        }

        final bool isMobile = MediaQuery.of(context).size.width < 768;

        Widget buildSidebarContent({required bool inDrawer}) {
          final content = Container(
            color: AppTheme.darkCard,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Logo
                Row(
                  children: [
                    const Icon(Icons.widgets_outlined, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      "SAKA Manage",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Navigation menus
                Expanded(
                  child: ListView.builder(
                    itemCount: menuItems.length,
                    itemBuilder: (context, idx) {
                      final item = menuItems[idx];
                      final isSelected = activeIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: InkWell(
                          onTap: () {
                            ref.read(activeMenuIndexProvider.notifier).state = idx;
                            if (inDrawer) {
                              Navigator.pop(context);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? const Border(left: BorderSide(color: AppTheme.primary, width: 3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  color: isSelected ? AppTheme.textMain : AppTheme.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.textMain : AppTheme.textMuted,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Profile/Logout
                const Divider(color: AppTheme.borderColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.role,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: AppTheme.danger, size: 18),
                      onPressed: () {
                        ref.read(authStateProvider.notifier).logout().then((_) {
                          context.go('/login');
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Developer Mode",
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(
                      height: 20,
                      child: Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: isDevMode,
                          activeColor: AppTheme.primary,
                          onChanged: (val) {
                            ref.read(developerModeProvider.notifier).toggle(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (inDrawer) ...[
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ServerSwitcherWidget(),
                  ),
                ],
              ],
            ),
          );

          if (inDrawer) {
            return SafeArea(child: content);
          }
          return content;
        }

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              title: Text(menuItems[activeIndex]['title'] as String),
            ),
            drawer: Drawer(
              width: 240,
              child: buildSidebarContent(inDrawer: true),
            ),
            body: SafeArea(
              child: activeView,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              // Left fixed Sidebar
              SizedBox(
                width: 240,
                child: buildSidebarContent(inDrawer: false),
              ),
              // Vertical divider line
              const VerticalDivider(width: 1, color: AppTheme.borderColor),
              // Main content area
              Expanded(
                child: Stack(
                  children: [
                    SafeArea(
                      child: activeView,
                    ),
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      right: 16,
                      child: const ServerSwitcherWidget(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text("Error loading workspace: $e"),
        ),
      ),
    );
  }
}

// --- Placeholder for inline specific views to avoid import issues ---

class ManagersListView extends ConsumerWidget {
  const ManagersListView({super.key});

  Future<List<dynamic>> _fetchPersonnel(WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/users');
    return response.data as List;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Personnel Roster", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text("Directory of all Bosses and Managers registered in the system.", style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchPersonnel(ref),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Failed to load users roster: ${snapshot.error}", style: const TextStyle(color: AppTheme.danger)));
                }
                final users = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, idx) {
                    final u = users[idx];
                    final bool isUserActive = u['active'] == 1 || u['active'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: u['role'] == 'BOSS' ? AppTheme.primary.withOpacity(0.2) : AppTheme.warning.withOpacity(0.2),
                          child: Icon(
                            u['role'] == 'BOSS' ? Icons.supervised_user_circle : Icons.engineering,
                            color: u['role'] == 'BOSS' ? AppTheme.primary : AppTheme.warning,
                          ),
                        ),
                        title: Text(u['username'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(u['email'] as String),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isUserActive ? AppTheme.success.withOpacity(0.12) : AppTheme.textMuted.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isUserActive ? 'ACTIVE' : 'DISABLED',
                                style: TextStyle(
                                  color: isUserActive ? AppTheme.success : AppTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(u['role'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                          ],
                        ),
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

class ManagerSummaryView extends ConsumerWidget {
  const ManagerSummaryView({super.key});

  Future<Map<String, dynamic>> _fetchSummaryStats(WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    final reportsResp = await client.get('/reports');
    final contactsResp = await client.get('/contacts');
    
    final reports = reportsResp.data as List;
    final contacts = contactsResp.data as List;
    
    final openReports = reports.where((r) => r['status'] == 'open').length;
    final pendingReports = reports.where((r) => r['status'] == 'followup_pending').length;
    final closedReports = reports.where((r) => r['status'] == 'closed').length;
    
    return {
      'total_reports': reports.length,
      'open_reports': openReports,
      'pending_reports': pendingReports,
      'closed_reports': closedReports,
      'total_contacts': contacts.length,
      'recent_reports': reports.take(3).toList(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSummaryStats(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error loading dashboard summary: ${snapshot.error}"));
        }
        
        final stats = snapshot.data!;
        final recentReports = stats['recent_reports'] as List;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Manager Dashboard", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text("Quick summary of your assigned clients and submitted reports.", style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 24),
              // KPI Cards
              isMobile
                  ? Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text("Assigned Clients", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                const SizedBox(height: 8),
                                Text("${stats['total_contacts']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text("Active Reports", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                const SizedBox(height: 8),
                                Text("${stats['open_reports'] + stats['pending_reports']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text("Closed Reports", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                const SizedBox(height: 8),
                                Text("${stats['closed_reports']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.success)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Assigned Clients", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Text("${stats['total_contacts']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Active Reports", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Text("${stats['open_reports'] + stats['pending_reports']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Closed Reports", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Text("${stats['closed_reports']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.success)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 32),
              // Recent reports list
              const Text("Recent Submissions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              recentReports.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text("You haven't submitted any reports yet.", style: TextStyle(color: AppTheme.textMuted))),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentReports.length,
                      itemBuilder: (context, index) {
                        final r = recentReports[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(r['summary'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Contact: ${r['contact_name'] ?? 'Unknown'} | Type: ${r['feedback_type']}"),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: r['priority'] == 'critical' ? AppTheme.danger.withOpacity(0.12) : AppTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (r['priority'] as String).toUpperCase(),
                                style: TextStyle(
                                  color: r['priority'] == 'critical' ? AppTheme.danger : AppTheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }
}
