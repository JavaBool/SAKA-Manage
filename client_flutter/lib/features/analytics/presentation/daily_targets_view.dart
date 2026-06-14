import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/analytics/models/daily_target_model.dart';

class DailyTargetsView extends ConsumerStatefulWidget {
  const DailyTargetsView({super.key});

  @override
  ConsumerState<DailyTargetsView> createState() => _DailyTargetsViewState();
}

class _DailyTargetsViewState extends ConsumerState<DailyTargetsView> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  
  DailySummaryModel? _summary;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBroadcasting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(analyticsRepositoryProvider);
      final summary = await repo.getDailySummary();
      _targetController.text = summary.targetContacts.toString();
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load target summary: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTarget() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(analyticsRepositoryProvider);
      final targetVal = int.parse(_targetController.text);
      await repo.setDailyTarget(targetVal);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Daily target updated successfully!"),
          backgroundColor: AppTheme.success,
        ),
      );
      
      await _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating target: $e"),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _broadcastSummary() async {
    setState(() {
      _isBroadcasting = true;
    });

    try {
      final repo = ref.read(analyticsRepositoryProvider);
      final success = await repo.sendDailySummaryNotification();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Daily summary notification broadcasted to all Bosses!"),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        throw Exception("Server returned non-200 status");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error broadcasting summary: $e"),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      setState(() {
        _isBroadcasting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final user = ref.watch(authStateProvider).value;
    final isBoss = user?.role == 'BOSS' || user?.role == 'ADMIN';

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_errorMessage != null || _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? "Error loading daily summary",
                style: const TextStyle(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary!;
    final progressVal = summary.targetContacts > 0 
        ? (summary.actualContactsHandled / summary.targetContacts).clamp(0.0, 1.0) 
        : 0.0;
    
    final progressPercent = (progressVal * 100).toInt();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
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
                      Text("Daily Targets", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text(
                        "Track manager performance and contact engagement goals.",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.primary),
                    onPressed: _fetchData,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Mobile layout is stacked, desktop is side-by-side
              isMobile
                  ? Column(
                      children: [
                        _buildProgressCard(progressVal, progressPercent, summary),
                        const SizedBox(height: 20),
                        if (isBoss) _buildBossControlCard(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildProgressCard(progressVal, progressPercent, summary),
                        ),
                        if (isBoss) ...[
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildBossControlCard(),
                          ),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(double progressVal, int progressPercent, DailySummaryModel summary) {
    final isTargetMet = summary.actualContactsHandled >= summary.targetContacts;
    
    return Card(
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "TODAY'S PROGRESS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 28),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progressVal,
                    strokeWidth: 12,
                    backgroundColor: Colors.white.withOpacity(0.04),
                    color: isTargetMet ? AppTheme.success : AppTheme.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$progressPercent%",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${summary.actualContactsHandled} / ${summary.targetContacts}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isTargetMet
                    ? AppTheme.success.withOpacity(0.08)
                    : AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTargetMet
                      ? AppTheme.success.withOpacity(0.2)
                      : AppTheme.primary.withOpacity(0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isTargetMet ? Icons.check_circle_outline : Icons.pending_outlined,
                    color: isTargetMet ? AppTheme.success : AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTargetMet 
                        ? "Daily Target Met successfully!" 
                        : "Target in progress. Keep updating reports!",
                    style: TextStyle(
                      color: isTargetMet ? AppTheme.success : AppTheme.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn("Reports Added", summary.reportsCountToday.toString()),
                _buildMetricColumn("Date Target Active", summary.date),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildBossControlCard() {
    return Card(
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TARGET CONFIGURATION",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Target Unique Contacts / Day",
                  hintText: "Enter target number (e.g. 15)",
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return "Please enter a value";
                  }
                  final intVal = int.tryParse(val);
                  if (intVal == null || intVal < 1) {
                    return "Please enter a positive integer";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTarget,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text("Save Daily Target"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const Divider(height: 32, color: AppTheme.borderColor),
              const Text(
                "BROADCAST SUMMARY",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Dispatch an instant FCM push notification summarizing today's goals to all active Bosses.",
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isBroadcasting ? null : _broadcastSummary,
                icon: _isBroadcasting 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: const Text("Broadcast Summary Alert"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
