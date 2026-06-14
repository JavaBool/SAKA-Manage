import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/contacts/models/contact_model.dart';
import 'package:client_flutter/features/products/models/product_model.dart';

class ReportCreateView extends ConsumerStatefulWidget {
  const ReportCreateView({super.key});

  @override
  ConsumerState<ReportCreateView> createState() => _ReportCreateViewState();
}

class _ReportCreateViewState extends ConsumerState<ReportCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _detailsController = TextEditingController();
  
  String? _selectedContactId;
  String? _selectedProductId;
  String _selectedFeedbackType = 'complaint';
  String _selectedPriority = 'medium';
  DateTime? _selectedFollowupDate;
  String? _localAttachmentPath;
  String? _attachmentName;

  List<ContactModel> _contacts = [];
  List<ProductModel> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final contacts = await ref.read(contactsRepositoryProvider).getContacts();
      final products = await ref.read(productsRepositoryProvider).getProducts();
      setState(() {
        _contacts = contacts;
        _products = products.where((p) => p.active).toList();
        if (_contacts.isNotEmpty) _selectedContactId = _contacts.first.id;
        if (_products.isNotEmpty) _selectedProductId = _products.first.id;
      });
    } catch (e) {
      print("Error loading form data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _localAttachmentPath = result.files.single.path;
        _attachmentName = result.files.single.name;
      });
    }
  }

  Future<void> _selectFollowupDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.darkCard,
              onSurface: AppTheme.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFollowupDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null || _selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a valid contact and product.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(reportsRepositoryProvider).createReport(
            contactId: _selectedContactId!,
            productId: _selectedProductId!,
            feedbackType: _selectedFeedbackType,
            summary: _summaryController.text.trim(),
            details: _detailsController.text.trim(),
            priority: _selectedPriority,
            status: 'open',
            nextFollowupDate: _selectedFollowupDate,
            localFilepath: _localAttachmentPath,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report created successfully! (Queued offline if network down)"),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating report: $e"), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Feedback Report"),
      ),
      body: _isLoading && _contacts.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Contact Selection
                    DropdownButtonFormField<String>(
                      value: _selectedContactId,
                      decoration: const InputDecoration(labelText: "Customer Contact"),
                      items: _contacts.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text("${c.name} (${c.company ?? 'Individual'})"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedContactId = val),
                    ),
                    const SizedBox(height: 16),
                    // Product Selection
                    DropdownButtonFormField<String>(
                      value: _selectedProductId,
                      decoration: const InputDecoration(labelText: "Product Line"),
                      items: _products.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedProductId = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Feedback Type
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFeedbackType,
                            decoration: const InputDecoration(labelText: "Feedback Type"),
                            items: const [
                              DropdownMenuItem(value: "positive", child: Text("Positive")),
                              DropdownMenuItem(value: "negative", child: Text("Negative")),
                              DropdownMenuItem(value: "complaint", child: Text("Complaint")),
                              DropdownMenuItem(value: "suggestion", child: Text("Suggestion")),
                              DropdownMenuItem(value: "feature_request", child: Text("Feature Request")),
                            ],
                            onChanged: (val) => setState(() => _selectedFeedbackType = val ?? 'complaint'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Priority
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPriority,
                            decoration: const InputDecoration(labelText: "Severity Priority"),
                            items: const [
                              DropdownMenuItem(value: "low", child: Text("LOW")),
                              DropdownMenuItem(value: "medium", child: Text("MEDIUM")),
                              DropdownMenuItem(value: "high", child: Text("HIGH")),
                              DropdownMenuItem(value: "critical", child: Text("CRITICAL")),
                            ],
                            onChanged: (val) => setState(() => _selectedPriority = val ?? 'medium'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Summary Input
                    TextFormField(
                      controller: _summaryController,
                      decoration: const InputDecoration(
                        labelText: "Feedback Summary",
                        hintText: "Brief title of the feedback...",
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "Summary is required" : null,
                    ),
                    const SizedBox(height: 16),
                    // Detailed Notes
                    TextFormField(
                      controller: _detailsController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: "Detailed Notes",
                        hintText: "Enter full details of the customer interaction...",
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "Detail details is required" : null,
                    ),
                    const SizedBox(height: 16),
                    // Followup date picker row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectFollowupDate,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              _selectedFollowupDate == null
                                  ? "Schedule Followup"
                                  : "Date: ${DateFormat('yyyy-MM-dd').format(_selectedFollowupDate!)}",
                            ),
                          ),
                        ),
                        if (_selectedFollowupDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.danger),
                            onPressed: () => setState(() => _selectedFollowupDate = null),
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Attachment picking
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, color: AppTheme.textMuted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _attachmentName ?? "No attachment selected",
                                style: TextStyle(
                                  color: _attachmentName == null ? AppTheme.textMuted : AppTheme.textMain,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _pickAttachment,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text("Browse"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SUBMIT REPORT"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
