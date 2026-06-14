import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Client Directory", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text("List of contacts and organizations assigned to you.", style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primary),
                  onPressed: _refreshContacts,
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
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, overflow: TextOverflow.ellipsis),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
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
