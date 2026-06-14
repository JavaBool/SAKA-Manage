import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/reports/models/report_model.dart';
import 'package:client_flutter/features/reports/presentation/report_create_view.dart';
import 'package:client_flutter/features/reports/presentation/report_detail_view.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  String _searchQuery = "";
  String _filterPriority = "";
  String _filterType = "";
  late Future<List<ReportModel>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _refreshReports();
  }

  void _refreshReports() {
    setState(() {
      _reportsFuture = ref.read(reportsRepositoryProvider).getReports();
    });
  }

  Color _getPriorityColor(String pr) {
    switch (pr.toLowerCase()) {
      case 'critical':
        return AppTheme.danger;
      case 'high':
        return const Color(0xFFFF5722);
      case 'medium':
        return AppTheme.warning;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final bool canCreate = user?.role == 'MANAGER' || user?.role == 'BOSS' || user?.role == 'ADMIN';

    final bool isMobile = MediaQuery.of(context).size.width < 768;

    final Widget searchField = TextField(
      decoration: const InputDecoration(
        hintText: "Search summary or details...",
        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
      ),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.toLowerCase();
        });
      },
    );

    final Widget priorityDropdown = DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Priority"),
      items: const [
        DropdownMenuItem(value: "", child: Text("All")),
        DropdownMenuItem(value: "low", child: Text("LOW")),
        DropdownMenuItem(value: "medium", child: Text("MEDIUM")),
        DropdownMenuItem(value: "high", child: Text("HIGH")),
        DropdownMenuItem(value: "critical", child: Text("CRITICAL")),
      ],
      onChanged: (val) {
        setState(() {
          _filterPriority = val ?? "";
        });
      },
    );

    final Widget feedbackDropdown = DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Feedback"),
      items: const [
        DropdownMenuItem(value: "", child: Text("All")),
        DropdownMenuItem(value: "positive", child: Text("Positive")),
        DropdownMenuItem(value: "negative", child: Text("Negative")),
        DropdownMenuItem(value: "complaint", child: Text("Complaint")),
        DropdownMenuItem(value: "suggestion", child: Text("Suggestion")),
        DropdownMenuItem(value: "feature_request", child: Text("Feature Request")),
      ],
      onChanged: (val) {
        setState(() {
          _filterType = val ?? "";
        });
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Customer Reports", style: Theme.of(context).textTheme.titleLarge),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primary),
                            onPressed: _refreshReports,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Audit logs of client feedback regarding products.", style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Customer Reports", style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text("Audit logs of client feedback regarding products.", style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.primary),
                        onPressed: _refreshReports,
                      )
                    ],
                  ),
            const SizedBox(height: 24),
            // Search & Filters row
            isMobile
                ? Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      priorityDropdown,
                      const SizedBox(height: 12),
                      feedbackDropdown,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: searchField,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: priorityDropdown,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: feedbackDropdown,
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            // Reports List
            Expanded(
              child: FutureBuilder<List<ReportModel>>(
                future: _reportsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error fetching reports: ${snapshot.error}", style: const TextStyle(color: AppTheme.danger)));
                  }
                  
                  final reports = snapshot.data ?? [];
                  final filtered = reports.where((r) {
                    final matchesSearch = r.summary.toLowerCase().contains(_searchQuery) ||
                        r.details.toLowerCase().contains(_searchQuery);
                    final matchesPriority = _filterPriority.isEmpty || r.priority.toLowerCase() == _filterPriority;
                    final matchesType = _filterType.isEmpty || r.feedbackType == _filterType;
                    return matchesSearch && matchesPriority && matchesType;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text("No feedback reports filed yet.", style: TextStyle(color: AppTheme.textMuted)));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final report = filtered[index];
                      final prColor = _getPriorityColor(report.priority);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ReportDetailView(reportId: report.id),
                            )).then((_) => _refreshReports());
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.summary,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: prColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        report.priority.toUpperCase(),
                                        style: TextStyle(
                                          color: prColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  report.details,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(report.contactName ?? 'Client', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.shopping_bag_outlined, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(report.productName ?? 'Product', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.borderColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        report.status.toUpperCase(),
                                        style: const TextStyle(color: AppTheme.textMain, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.assignment_ind_outlined, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text("Handler: ${report.managerUsername ?? 'Unknown'}", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
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
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const ReportCreateView(),
                )).then((_) => _refreshReports());
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
