import 'dart:convert' show utf8;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/contacts/models/contact_model.dart';

class ContactsView extends ConsumerStatefulWidget {
  const ContactsView({super.key});

  @override
  ConsumerState<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends ConsumerState<ContactsView> {
  String _searchQuery = "";
  late Future<List<ContactModel>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _refreshContacts();
  }

  void _refreshContacts() {
    setState(() {
      _contactsFuture = ref.read(contactsRepositoryProvider).getContacts();
    });
  }

  List<List<String>> parseCSV(String text) {
    final List<List<String>> lines = [];
    List<String> row = [""];
    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final String char = text[i];
      final String? nextChar = (i + 1 < text.length) ? text[i + 1] : null;

      if (char == '"') {
        if (inQuotes && nextChar == '"') {
          row[row.length - 1] += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add('');
      } else if ((char == '\r' || char == '\n') && !inQuotes) {
        if (char == '\r' && nextChar == '\n') {
          i++;
        }
        lines.add(row);
        row = [''];
      } else {
        row[row.length - 1] += char;
      }
    }
    if (row.length > 1 || row[0].isNotEmpty) {
      lines.add(row);
    }
    return lines;
  }

  Map<String, int> mapHeaders(List<String> headers) {
    final Map<String, int> mapping = {};
    for (int idx = 0; idx < headers.length; idx++) {
      final clean = headers[idx].trim().toLowerCase();
      if (clean == 'name' || clean == 'full name' || clean == 'contact name') {
        mapping['name'] = idx;
      } else if (clean == 'company' || clean == 'company name' || clean == 'organization') {
        mapping['company'] = idx;
      } else if (clean == 'designation' || clean == 'title' || clean == 'role' || clean == 'job title') {
        mapping['designation'] = idx;
      } else if (clean == 'phone' || clean == 'phone number' || clean == 'tel' || clean == 'mobile') {
        mapping['phone'] = idx;
      } else if (clean == 'email' || clean == 'email address') {
        mapping['email'] = idx;
      } else if (clean == 'address' || clean == 'street' || clean == 'location') {
        mapping['address'] = idx;
      } else if (clean == 'website' || clean == 'url' || clean == 'web') {
        mapping['website'] = idx;
      }
    }
    return mapping;
  }

  void _showCsvInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary),
              SizedBox(width: 8),
              Text("CSV Import Guide", style: TextStyle(color: AppTheme.textMain)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "To import contacts, select a standard CSV file. The file should have a header row and follow the columns described below:",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                SizedBox(height: 12),
                Text(
                  "Supported Columns:",
                  style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  "• Name / Full Name / Contact Name (Required)\n"
                  "• Company / Company Name / Organization\n"
                  "• Designation / Title / Role / Job Title\n"
                  "• Phone / Phone Number / Tel / Mobile\n"
                  "• Email / Email Address\n"
                  "• Website / URL / Web\n"
                  "• Address / Street / Location",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                ),
                SizedBox(height: 12),
                Text(
                  "Conflict Resolution:",
                  style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  "If a contact with the same name already exists in the directory, you will be asked to choose:\n"
                  "1. Discard: Skip importing this duplicate contact.\n"
                  "2. Update Details: Merge the CSV details into the existing contact.\n"
                  "3. Rename & Add: Save as a new contact under a custom name.",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Got it", style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCsv() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String csvText = "";

      if (file.bytes != null) {
        csvText = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final ioFile = io.File(file.path!);
        csvText = await ioFile.readAsString();
      } else {
        return;
      }

      final lines = parseCSV(csvText);
      if (lines.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The selected CSV file appears to be empty or invalid.')),
          );
        }
        return;
      }

      final headers = lines[0];
      final mapping = mapHeaders(headers);

      if (mapping['name'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The CSV file must contain a "Name" column.')),
          );
        }
        return;
      }

      final List<Map<String, String>> contactsToImport = [];
      for (int i = 1; i < lines.length; i++) {
        final values = lines[i];
        if (values.length < headers.length) continue;

        final Map<String, String> contact = {};
        if (mapping['name'] != null) contact['name'] = values[mapping['name']!].trim();
        if (mapping['company'] != null) contact['company'] = values[mapping['company']!].trim();
        if (mapping['designation'] != null) contact['designation'] = values[mapping['designation']!].trim();
        if (mapping['phone'] != null) contact['phone'] = values[mapping['phone']!].trim();
        if (mapping['email'] != null) contact['email'] = values[mapping['email']!].trim();
        if (mapping['website'] != null) contact['website'] = values[mapping['website']!].trim();
        if (mapping['address'] != null) contact['address'] = values[mapping['address']!].trim();

        if (contact['name'] != null && contact['name']!.isNotEmpty) {
          contactsToImport.add(contact);
        }
      }

      if (contactsToImport.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid contacts found in the CSV.')),
          );
        }
        return;
      }

      final allContacts = await _contactsFuture;
      final Map<String, ContactModel> existingContacts = {};
      for (var c in allContacts) {
        existingContacts[c.name.trim().toLowerCase()] = c;
      }

      if (!mounted) return;

      int importedCount = 0;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Importing contacts...", style: TextStyle(color: AppTheme.textMain)),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        for (var contact in contactsToImport) {
          final String name = contact['name']!;
          final String lowerName = name.trim().toLowerCase();

          if (existingContacts.containsKey(lowerName)) {
            if (context.mounted) Navigator.pop(context);

            final resolutionResult = await showDialog<Map<String, dynamic>>(
              context: context,
              barrierDismissible: false,
              builder: (context) => ConflictResolutionDialog(contactName: name),
            );

            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Importing contacts...", style: TextStyle(color: AppTheme.textMain)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final action = resolutionResult?['action'] as ConflictResolution?;
            if (action == null || action == ConflictResolution.discard) {
              continue;
            }

            if (action == ConflictResolution.update) {
              final existing = existingContacts[lowerName]!;
              final payload = {
                'name': name,
                'company': contact['company']?.isNotEmpty == true ? contact['company'] : (existing.company ?? ''),
                'designation': contact['designation']?.isNotEmpty == true ? contact['designation'] : (existing.designation ?? ''),
                'phone': contact['phone']?.isNotEmpty == true ? contact['phone'] : (existing.phone ?? ''),
                'email': contact['email']?.isNotEmpty == true ? contact['email'] : (existing.email ?? ''),
                'website': contact['website']?.isNotEmpty == true ? contact['website'] : (existing.website ?? ''),
                'address': contact['address']?.isNotEmpty == true ? contact['address'] : (existing.address ?? ''),
                'assigned_manager_id': existing.assignedManagerId,
              };
              await ref.read(contactsRepositoryProvider).updateContact(existing.id, payload);
            } else if (action == ConflictResolution.rename) {
              final String newName = resolutionResult?['name'] as String;
              final payload = {
                'name': newName,
                'company': contact['company']?.isNotEmpty == true ? contact['company'] : null,
                'designation': contact['designation']?.isNotEmpty == true ? contact['designation'] : null,
                'phone': contact['phone']?.isNotEmpty == true ? contact['phone'] : null,
                'email': contact['email']?.isNotEmpty == true ? contact['email'] : null,
                'website': contact['website']?.isNotEmpty == true ? contact['website'] : null,
                'address': contact['address']?.isNotEmpty == true ? contact['address'] : null,
              };
              await ref.read(contactsRepositoryProvider).createContact(payload);
              existingContacts[newName.trim().toLowerCase()] = ContactModel(
                id: '',
                name: newName,
                company: payload['company'],
                designation: payload['designation'],
                phone: payload['phone'],
                email: payload['email'],
                website: payload['website'],
                address: payload['address'],
              );
            }
          } else {
            final payload = {
              'name': name,
              'company': contact['company']?.isNotEmpty == true ? contact['company'] : null,
              'designation': contact['designation']?.isNotEmpty == true ? contact['designation'] : null,
              'phone': contact['phone']?.isNotEmpty == true ? contact['phone'] : null,
              'email': contact['email']?.isNotEmpty == true ? contact['email'] : null,
              'website': contact['website']?.isNotEmpty == true ? contact['website'] : null,
              'address': contact['address']?.isNotEmpty == true ? contact['address'] : null,
            };
            await ref.read(contactsRepositoryProvider).createContact(payload);
            existingContacts[lowerName] = ContactModel(
              id: '',
              name: name,
              company: payload['company'],
              designation: payload['designation'],
              phone: payload['phone'],
              email: payload['email'],
              website: payload['website'],
              address: payload['address'],
            );
          }
          importedCount++;
        }
      } finally {
        if (context.mounted) Navigator.pop(context);
      }

      _refreshContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $importedCount contacts.')),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return;
    
    // Add protocol if missing
    Uri uri = Uri.parse(cleanUrl);
    if (!uri.hasScheme) {
      uri = Uri.parse('https://$cleanUrl');
    }
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $cleanUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching website: $e')),
        );
      }
    }
  }

  String _displayUrl(String url) {
    // Strip http://, https://, and www. to make the display cleaner
    var display = url.replaceFirst(RegExp(r'^https?://'), '');
    display = display.replaceFirst(RegExp(r'^www\.'), '');
    // If it's too long, truncate it
    if (display.length > 20) {
      return '${display.substring(0, 17)}...';
    }
    return display;
  }

  void _showContactForm({ContactModel? contact}) async {
    final bool isEdit = contact != null;
    final nameController = TextEditingController(text: contact?.name ?? '');
    final companyController = TextEditingController(text: contact?.company ?? '');
    final designationController = TextEditingController(text: contact?.designation ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');
    final websiteController = TextEditingController(text: contact?.website ?? '');
    final addressController = TextEditingController(text: contact?.address ?? '');
    
    String? selectedManagerId = contact?.assignedManagerId;
    List<Map<String, dynamic>> managers = [];
    final currentUser = ref.read(authStateProvider).value;
    final bool showManagerSelector = currentUser != null && (currentUser.role == 'BOSS' || currentUser.role == 'ADMIN');

    if (showManagerSelector) {
      try {
        final response = await ref.read(apiClientProvider).get('/users');
        if (response.statusCode == 200) {
          final List<dynamic> users = response.data as List;
          managers = users
              .where((u) => u['role'] == 'MANAGER' && u['active'] == true)
              .map((u) => {
                    'id': u['id'] as String,
                    'username': u['username'] as String,
                  })
              .toList();
        }
      } catch (e) {
        print("Error fetching managers for form: $e");
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Text(isEdit ? 'Edit Contact' : 'Create Contact', style: const TextStyle(color: AppTheme.textMain)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(labelText: 'Name *', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: companyController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(labelText: 'Company', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: designationController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(labelText: 'Designation', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: websiteController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(labelText: 'Website', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        style: const TextStyle(color: AppTheme.textMain),
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Address', labelStyle: TextStyle(color: AppTheme.textMuted)),
                      ),
                      if (showManagerSelector) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedManagerId,
                          dropdownColor: AppTheme.darkCard,
                          decoration: const InputDecoration(
                            labelText: 'Assign Manager',
                            labelStyle: TextStyle(color: AppTheme.textMuted),
                          ),
                          style: const TextStyle(color: AppTheme.textMain),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Unassigned', style: TextStyle(color: AppTheme.textMuted)),
                            ),
                            ...managers.map((m) => DropdownMenuItem<String>(
                                  value: m['id'],
                                  child: Text(m['username']!, style: const TextStyle(color: AppTheme.textMain)),
                                )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedManagerId = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name is required')),
                      );
                      return;
                    }
                    
                    final payload = {
                      'name': name,
                      'company': companyController.text.trim().isEmpty ? null : companyController.text.trim(),
                      'designation': designationController.text.trim().isEmpty ? null : designationController.text.trim(),
                      'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                      'website': websiteController.text.trim().isEmpty ? null : websiteController.text.trim(),
                      'address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                      if (showManagerSelector) 'assigned_manager_id': selectedManagerId,
                    };

                    try {
                      bool success;
                      if (isEdit) {
                        success = await ref.read(contactsRepositoryProvider).updateContact(contact.id, payload);
                      } else {
                        success = await ref.read(contactsRepositoryProvider).createContact(payload);
                      }

                      if (success) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          _refreshContacts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEdit ? 'Contact updated' : 'Contact created')),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving contact: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteContact(ContactModel contact) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Delete Contact', style: TextStyle(color: AppTheme.textMain)),
          content: Text('Are you sure you want to permanently delete "${contact.name}"?', style: const TextStyle(color: AppTheme.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final success = await ref.read(contactsRepositoryProvider).deleteContact(contact.id);
                  if (success) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      _refreshContacts();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contact deleted')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting contact: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final bool canCreate = currentUser != null;

    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _showContactForm(),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
                          Text("Client Directory", style: Theme.of(context).textTheme.titleLarge),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primary),
                            onPressed: _refreshContacts,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("List of contacts and organizations assigned to you.", style: TextStyle(color: AppTheme.textMuted)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _importCsv,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text("Import CSV"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.darkCard,
                                foregroundColor: AppTheme.textMain,
                                side: const BorderSide(color: AppTheme.borderColor),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.info_outline, color: AppTheme.primary),
                            tooltip: 'CSV Import Guide',
                            onPressed: _showCsvInfoDialog,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Client Directory", style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text("List of contacts and organizations assigned to you.", style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _importCsv,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text("Import CSV"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkCard,
                              foregroundColor: AppTheme.textMain,
                              side: const BorderSide(color: AppTheme.borderColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.info_outline, color: AppTheme.primary),
                            tooltip: 'CSV Import Guide',
                            onPressed: _showCsvInfoDialog,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primary),
                            onPressed: _refreshContacts,
                          ),
                        ],
                      )
                    ],
                  ),
            const SizedBox(height: 24),
            // Search box
            TextField(
              decoration: const InputDecoration(
                hintText: "Search contacts by name or company...",
                prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 20),
            // Table/List
            Expanded(
              child: FutureBuilder<List<ContactModel>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Error fetching contacts: ${snapshot.error}", style: const TextStyle(color: AppTheme.danger)),
                    );
                  }
                  
                  final allContacts = snapshot.data ?? [];
                  final filtered = allContacts.where((c) {
                    final name = c.name.toLowerCase();
                    final comp = (c.company ?? "").toLowerCase();
                    return name.contains(_searchQuery) || comp.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text("No contacts found.", style: TextStyle(color: AppTheme.textMuted)),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final bool canManage = currentUser != null &&
                          (currentUser.role == 'BOSS' ||
                              currentUser.role == 'ADMIN' ||
                              (currentUser.role == 'MANAGER' && contact.assignedManagerId == currentUser.id));

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primary.withOpacity(0.12),
                                child: const Icon(Icons.person, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${contact.designation ?? 'Representative'} at ${contact.company ?? 'Individual'}",
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                    if (contact.address != null && contact.address!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        contact.address!,
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                      ),
                                    ],
                                    if (isMobile) ...[
                                      const SizedBox(height: 8),
                                      const Divider(height: 12, color: AppTheme.borderColor),
                                      if (contact.phone != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone, size: 12, color: AppTheme.textMuted),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  contact.phone!,
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (contact.email != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.email, size: 12, color: AppTheme.textMuted),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  contact.email!,
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (contact.website != null && contact.website!.isNotEmpty)
                                        InkWell(
                                          onTap: () => _launchUrl(contact.website!),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.language, size: 12, color: AppTheme.primary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _displayUrl(contact.website!),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.primary,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (contact.phone != null)
                                      Text(contact.phone!, style: const TextStyle(fontSize: 12, color: AppTheme.textMain)),
                                    if (contact.email != null)
                                      Text(contact.email!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                    if (contact.website != null && contact.website!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _launchUrl(contact.website!),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.language, size: 12, color: AppTheme.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              _displayUrl(contact.website!),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.primary,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              if (canManage) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _showContactForm(contact: contact);
                                    } else if (val == 'delete') {
                                      _confirmDeleteContact(contact);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 16, color: AppTheme.textMain),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 16, color: AppTheme.danger),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: AppTheme.danger)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }
}

enum ConflictResolution { update, rename, discard }

class ConflictResolutionDialog extends StatefulWidget {
  final String contactName;

  const ConflictResolutionDialog({super.key, required this.contactName});

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  final _nameController = TextEditingController();
  bool _showRenameField = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = "${widget.contactName} (Copy)";
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: const Text('Duplicate Contact Detected', style: TextStyle(color: AppTheme.textMain)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A contact with the name "${widget.contactName}" already exists in the system.',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please choose how you would like to resolve this conflict:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            if (_showRenameField) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: const InputDecoration(
                  labelText: 'New Unique Name',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, {'action': ConflictResolution.discard});
          },
          child: const Text('Discard', style: TextStyle(color: AppTheme.danger)),
        ),
        if (!_showRenameField)
          TextButton(
            onPressed: () {
              setState(() {
                _showRenameField = true;
              });
            },
            child: const Text('Rename & Add', style: TextStyle(color: AppTheme.textMain)),
          )
        else
          TextButton(
            onPressed: () {
              final newName = _nameController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New name cannot be empty')),
                );
                return;
              }
              Navigator.pop(context, {
                'action': ConflictResolution.rename,
                'name': newName,
              });
            },
            child: const Text('Save Renamed', style: TextStyle(color: AppTheme.primary)),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {'action': ConflictResolution.update});
          },
          child: const Text('Update Details'),
        ),
      ],
    );
  }
}
