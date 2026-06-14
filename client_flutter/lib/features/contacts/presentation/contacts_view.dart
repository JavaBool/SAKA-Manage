import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                              ],
                            )
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
