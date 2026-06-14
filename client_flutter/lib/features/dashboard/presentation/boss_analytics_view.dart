import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';

class BossAnalyticsView extends ConsumerStatefulWidget {
  const BossAnalyticsView({super.key});

  @override
  ConsumerState<BossAnalyticsView> createState() => _BossAnalyticsViewState();
}

class _BossAnalyticsViewState extends ConsumerState<BossAnalyticsView> {
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _refreshAnalytics();
  }

  void _refreshAnalytics() {
    setState(() {
      _analyticsFuture = _fetchAnalytics();
    });
  }

  Future<Map<String, dynamic>> _fetchAnalytics() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/analytics');
    return response.data as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Failed to load analytics: ${snapshot.error}",
                      style: const TextStyle(color: AppTheme.danger),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshAnalytics,
                      child: const Text("Retry"),
                    )
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
          final charts = data['charts'] as Map<String, dynamic>? ?? {};

          final totalReports = metrics['total_reports'] ?? 0;
          final reportsToday = metrics['reports_today'] ?? 0;
          final openReports = metrics['open_reports'] ?? 0;
          final closedReports = metrics['closed_reports'] ?? 0;
          final pendingReports = metrics['followup_pending_reports'] ?? 0;
          final criticalReports = metrics['critical_reports'] ?? 0;
          final followupsDue = metrics['followups_due'] ?? 0;
          final activeManagers = metrics['active_managers'] ?? 0;
          final completionRate = (metrics['completion_rate'] as num?)?.toDouble() ?? 100.0;

          final reportsByProduct = charts['reports_by_product'] as Map<String, dynamic>? ?? {};
          final reportsByManager = charts['reports_by_manager'] as Map<String, dynamic>? ?? {};
          final priorityDistribution = charts['priority_distribution'] as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Executive Analytics", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text("System-wide metrics and trends overview for SAKA Manage.", style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primary),
                      onPressed: _refreshAnalytics,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // KPI Grid
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                  children: [
                    _buildKpiCard("Total Submissions", "$totalReports", Icons.description_outlined, AppTheme.primary),
                    _buildKpiCard("Today's Intake", "$reportsToday", Icons.today_outlined, AppTheme.secondary),
                    _buildKpiCard("Critical Alerts", "$criticalReports", Icons.warning_amber_rounded, AppTheme.danger, isWarning: criticalReports > 0),
                    _buildKpiCard("Follow-ups Due", "$followupsDue", Icons.notification_important_outlined, AppTheme.warning, isWarning: followupsDue > 0),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                  children: [
                    _buildKpiCard("Open Reports", "$openReports", Icons.lock_open, AppTheme.warning),
                    _buildKpiCard("Pending Progress", "$pendingReports", Icons.hourglass_empty, AppTheme.secondary),
                    _buildKpiCard("Closed & Resolved", "$closedReports", Icons.lock_outline, AppTheme.success),
                    _buildKpiCard("Managers Active", "$activeManagers", Icons.people_outline, AppTheme.success),
                  ],
                ),
                const SizedBox(height: 24),

                // Middle Section: Completion rate & priority distribution
                isMobile
                    ? Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Resolution Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 140,
                                          height: 140,
                                          child: CircularProgressIndicator(
                                            value: completionRate / 100.0,
                                            strokeWidth: 12,
                                            backgroundColor: AppTheme.borderColor,
                                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            Text("${completionRate.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                            const Text("Closed", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLegendRow("Resolved Reports", "$closedReports", AppTheme.success),
                                  const Divider(height: 20, color: AppTheme.borderColor),
                                  _buildLegendRow("Active Backlog", "${openReports + pendingReports}", AppTheme.warning),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Priority Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 24),
                                  _buildPriorityBar("Critical", priorityDistribution['critical'] ?? 0, totalReports, AppTheme.danger),
                                  const SizedBox(height: 14),
                                  _buildPriorityBar("High", priorityDistribution['high'] ?? 0, totalReports, AppTheme.secondary),
                                  const SizedBox(height: 14),
                                  _buildPriorityBar("Medium", priorityDistribution['medium'] ?? 0, totalReports, AppTheme.primary),
                                  const SizedBox(height: 14),
                                  _buildPriorityBar("Low", priorityDistribution['low'] ?? 0, totalReports, AppTheme.success),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Resolution Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 20),
                                    Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 140,
                                            height: 140,
                                            child: CircularProgressIndicator(
                                              value: completionRate / 100.0,
                                              strokeWidth: 12,
                                              backgroundColor: AppTheme.borderColor,
                                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              Text("${completionRate.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                              const Text("Closed", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildLegendRow("Resolved Reports", "$closedReports", AppTheme.success),
                                    const Divider(height: 20, color: AppTheme.borderColor),
                                    _buildLegendRow("Active Backlog", "${openReports + pendingReports}", AppTheme.warning),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: Card(
                              child: Padding(
                                                            padding: const EdgeInsets.all(20.0),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                const Text("Priority Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                                const SizedBox(height: 24),
                                                                _buildPriorityBar("Critical", priorityDistribution['critical'] ?? 0, totalReports, AppTheme.danger),
                                                                const SizedBox(height: 14),
                                                                _buildPriorityBar("High", priorityDistribution['high'] ?? 0, totalReports, AppTheme.secondary),
                                                                const SizedBox(height: 14),
                                                                _buildPriorityBar("Medium", priorityDistribution['medium'] ?? 0, totalReports, AppTheme.primary),
                                                                const SizedBox(height: 14),
                                                                _buildPriorityBar("Low", priorityDistribution['low'] ?? 0, totalReports, AppTheme.success),
                                                              ],
                                                            ),
                              ),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),

                // Bottom Section: Reports by Product & Manager
                isMobile
                    ? Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Submissions by Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 16),
                                  reportsByProduct.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 32.0),
                                          child: Center(child: Text("No product reports registered yet.", style: TextStyle(color: AppTheme.textMuted))),
                                        )
                                      : Column(
                                          children: reportsByProduct.entries.map((e) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12.0),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.shopping_bag_outlined, color: AppTheme.primary, size: 20),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primary.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      "${e.value}",
                                                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Submissions by Manager", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 16),
                                  reportsByManager.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 32.0),
                                          child: Center(child: Text("No manager reports registered yet.", style: TextStyle(color: AppTheme.textMuted))),
                                        )
                                      : Column(
                                          children: reportsByManager.entries.map((e) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12.0),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.person_outline, color: AppTheme.secondary, size: 20),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.secondary.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      "${e.value}",
                                                      style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Submissions by Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 16),
                                    reportsByProduct.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 32.0),
                                            child: Center(child: Text("No product reports registered yet.", style: TextStyle(color: AppTheme.textMuted))),
                                          )
                                        : Column(
                                            children: reportsByProduct.entries.map((e) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 12.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.shopping_bag_outlined, color: AppTheme.primary, size: 20),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primary.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        "${e.value}",
                                                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Submissions by Manager", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 16),
                                    reportsByManager.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 32.0),
                                            child: Center(child: Text("No manager reports registered yet.", style: TextStyle(color: AppTheme.textMuted))),
                                          )
                                        : Column(
                                            children: reportsByManager.entries.map((e) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 12.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.person_outline, color: AppTheme.secondary, size: 20),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.secondary.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        "${e.value}",
                                                        style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, {bool isWarning = false}) {
    return Card(
      color: isWarning ? color.withOpacity(0.08) : AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: isWarning ? color : AppTheme.textMain
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(String title, String count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: AppTheme.textMuted)),
          ],
        ),
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPriorityBar(String label, int count, int total, Color color) {
    final double pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text("$count (${(pct * 100).toStringAsFixed(1)}%)", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
