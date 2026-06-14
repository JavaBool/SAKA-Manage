import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/reports/models/report_model.dart';
import 'package:client_flutter/features/reports/models/followup_model.dart';
import 'package:client_flutter/features/contacts/models/contact_model.dart';


class ReportDetailView extends ConsumerStatefulWidget {
  final String reportId;
  const ReportDetailView({super.key, required this.reportId});

  @override
  ConsumerState<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends ConsumerState<ReportDetailView> {
  final _followupController = TextEditingController();
  late Future<ReportModel> _reportFuture;
  late Future<List<FollowupModel>> _followupsFuture;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _reportFuture = ref.read(reportsRepositoryProvider).getReports().then(
            (list) => list.firstWhere((r) => r.id == widget.reportId),
          );
      _followupsFuture = ref.read(reportsRepositoryProvider).getFollowups(widget.reportId);
    });
  }

  Future<void> _submitFollowup() async {
    final notes = _followupController.text.trim();
    if (notes.isEmpty) return;

    setState(() {
      _isActionLoading = true;
    });

    try {
      await ref.read(reportsRepositoryProvider).createFollowup(widget.reportId, notes);
      _followupController.clear();
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Follow-up logged successfully!"), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to log follow-up: $e"), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(ReportModel report, String newStatus) async {
    setState(() {
      _isActionLoading = true;
    });

    final updatedReport = ReportModel(
      id: report.id,
      contactId: report.contactId,
      managerId: report.managerId,
      productId: report.productId,
      feedbackType: report.feedbackType,
      summary: report.summary,
      details: report.details,
      priority: report.priority,
      status: newStatus,
      nextFollowupDate: report.nextFollowupDate,
      createdAt: report.createdAt,
      updatedAt: DateTime.now().toUtc(),
      contactName: report.contactName,
      contactCompany: report.contactCompany,
      productName: report.productName,
      managerUsername: report.managerUsername,
    );

    try {
      await ref.read(reportsRepositoryProvider).updateReport(updatedReport);
      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e"), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _followupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Detail Summary"),
      ),
      body: SafeArea(
        child: FutureBuilder<ReportModel>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error}", style: const TextStyle(color: AppTheme.danger)),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: Text("Report not found."));
            }

            final report = snapshot.data!;
            final bool isCreator = user != null && user.id == report.managerId;

            return FutureBuilder<ContactModel?>(
              future: ref.read(contactsRepositoryProvider).getContactById(report.contactId),
              builder: (context, contactSnapshot) {
                final contact = contactSnapshot.data;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header details
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.summary,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, size: 16, color: AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    report.productName ?? 'Product Line',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.assignment_ind_outlined, size: 16, color: AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Handled by: ${report.managerUsername ?? 'Unknown'}",
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Contact Details Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_outline, size: 16, color: AppTheme.primary),
                                  SizedBox(width: 6),
                                  Text(
                                    "CLIENT CONTACT DETAILS",
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                contact?.name ?? report.contactName ?? 'Client',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if ((contact?.designation ?? "").isNotEmpty ||
                                  (contact?.company ?? "").isNotEmpty ||
                                  (report.contactCompany ?? "").isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "${contact?.designation ?? ''}${(contact?.designation ?? "").isNotEmpty && (contact?.company ?? report.contactCompany ?? "").isNotEmpty ? ' at ' : ''}${contact?.company ?? report.contactCompany ?? ''}",
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                              ],
                              const Divider(height: 24, color: AppTheme.borderColor),
                              if (contact?.phone != null && contact!.phone!.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16, color: AppTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Text(contact.phone!, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (contact?.email != null && contact!.email!.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 16, color: AppTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Text(contact.email!, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (contact?.website != null && contact!.website!.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.language_outlined, size: 16, color: AppTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Text(contact.website!, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (contact?.address != null && contact!.address!.isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        contact.address!,
                                        style: const TextStyle(fontSize: 13, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (contact == null && contactSnapshot.connectionState == ConnectionState.waiting) ...[
                                const Center(
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                  ),
                                )
                              ] else ...[
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "No additional contact details registered.",
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metadata parameters
                      Builder(
                        builder: (context) {
                          final bool isMobile = MediaQuery.of(context).size.width < 600;

                          final Widget priorityWidget = Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("PRIORITY", style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.priority.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final Widget typeWidget = Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("FEEDBACK TYPE", style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.feedbackType.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final String followupStr = report.nextFollowupDate != null
                              ? DateFormat('yyyy-MM-dd').format(report.nextFollowupDate!.toLocal())
                              : 'None Scheduled';

                          final Widget followupWidget = Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("NEXT FOLLOW-UP", style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_outlined,
                                        size: 16,
                                        color: report.nextFollowupDate != null ? AppTheme.warning : AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        followupStr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: report.nextFollowupDate != null ? AppTheme.warning : AppTheme.textMain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          return isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    priorityWidget,
                                    const SizedBox(height: 8),
                                    typeWidget,
                                    const SizedBox(height: 8),
                                    followupWidget,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: priorityWidget),
                                    const SizedBox(width: 12),
                                    Expanded(child: typeWidget),
                                    const SizedBox(width: 12),
                                    Expanded(child: followupWidget),
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status modifier row
                      Builder(
                        builder: (context) {
                          final bool isMobile = MediaQuery.of(context).size.width < 600;

                          final Widget statusText = const Text(
                            "Current Ticket Status:",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain),
                          );

                          final Widget actions = isCreator && report.status != 'closed'
                              ? Row(
                                  mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                                  children: [
                                    isMobile
                                        ? Expanded(
                                            child: ElevatedButton(
                                              onPressed: _isActionLoading ? null : () => _updateStatus(report, 'followup_pending'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.warning.withOpacity(0.2),
                                                foregroundColor: AppTheme.warning,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              child: const Text("PENDING", style: TextStyle(fontSize: 12)),
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: _isActionLoading ? null : () => _updateStatus(report, 'followup_pending'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.warning.withOpacity(0.2),
                                              foregroundColor: AppTheme.warning,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            child: const Text("PENDING", style: TextStyle(fontSize: 12)),
                                          ),
                                    const SizedBox(width: 8),
                                    isMobile
                                        ? Expanded(
                                            child: ElevatedButton(
                                              onPressed: _isActionLoading ? null : () => _updateStatus(report, 'closed'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.success.withOpacity(0.2),
                                                foregroundColor: AppTheme.success,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              child: const Text("CLOSE TICKET", style: TextStyle(fontSize: 12)),
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: _isActionLoading ? null : () => _updateStatus(report, 'closed'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.success.withOpacity(0.2),
                                              foregroundColor: AppTheme.success,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            child: const Text("CLOSE TICKET", style: TextStyle(fontSize: 12)),
                                          ),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    report.status.toUpperCase(),
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                );

                          return isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    statusText,
                                    const SizedBox(height: 12),
                                    actions,
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    statusText,
                                    actions,
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Detailed Notes
                      const Text("Detailed Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          report.details,
                          style: const TextStyle(color: AppTheme.textMain, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Followup Timeline logs
                      const Text("Followup Progress logs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      FutureBuilder<List<FollowupModel>>(
                        future: _followupsFuture,
                        builder: (context, fSnapshot) {
                          if (fSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                          }
                          final followups = fSnapshot.data ?? [];
                          if (followups.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text("No progress followups logged yet.", style: TextStyle(color: AppTheme.textMuted)),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: followups.length,
                            itemBuilder: (context, idx) {
                              final f = followups[idx];
                              final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(f.createdAt.toLocal());
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            f.managerUsername ?? 'Manager',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12),
                                          ),
                                          Text(dateStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(f.notes, style: const TextStyle(color: AppTheme.textMain, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Log Followup notes form (for Creator only)
                      if (isCreator && report.status != 'closed') ...[
                        TextField(
                          controller: _followupController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "Log Follow-up notes",
                            hintText: "Enter customer call notes, meeting actions, etc...",
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isActionLoading ? null : _submitFollowup,
                          child: _isActionLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("SAVE PROGRESS NOTE"),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
