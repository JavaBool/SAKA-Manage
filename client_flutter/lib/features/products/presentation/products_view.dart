import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';
import 'package:client_flutter/features/products/models/product_model.dart';

class ProductsView extends ConsumerStatefulWidget {
  const ProductsView({super.key});

  @override
  ConsumerState<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends ConsumerState<ProductsView> {
  late Future<List<ProductModel>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = ref.read(productsRepositoryProvider).getProducts();
    });
  }

  void _showProductForm({ProductModel? product}) {
    final bool isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    bool isActive = product?.active ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Text(
                isEdit ? 'Edit Product' : 'Create Product',
                style: const TextStyle(color: AppTheme.textMain),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          labelStyle: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        style: const TextStyle(color: AppTheme.textMain),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text(
                          'Active',
                          style: TextStyle(color: AppTheme.textMain),
                        ),
                        subtitle: const Text(
                          'Managers can only select active products for reports.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        value: isActive,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                          setDialogState(() {
                            isActive = val;
                          });
                        },
                      ),
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
                        const SnackBar(content: Text('Product name is required')),
                      );
                      return;
                    }

                    final payload = {
                      'name': name,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'active': isActive,
                    };

                    try {
                      bool success;
                      if (isEdit) {
                        success = await ref
                            .read(productsRepositoryProvider)
                            .updateProduct(product.id, payload);
                      } else {
                        success = await ref
                            .read(productsRepositoryProvider)
                            .createProduct(payload);
                      }

                      if (success) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          _refreshProducts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Product updated successfully' : 'Product created successfully',
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving product: $e')),
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

  void _confirmDeleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Delete Product', style: TextStyle(color: AppTheme.textMain)),
          content: Text(
            'Are you sure you want to permanently delete "${product.name}"? This will delete all associated reports.',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final success = await ref
                      .read(productsRepositoryProvider)
                      .deleteProduct(product.id);
                  if (success) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      _refreshProducts();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Product deleted')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting product: $e')),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductForm(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                    Text("Products Directory", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text("Manage products and services catalog.", style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primary),
                  onPressed: _refreshProducts,
                )
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<ProductModel>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error fetching products: ${snapshot.error}",
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                    );
                  }

                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return const Center(
                      child: Text("No products found.", style: TextStyle(color: AppTheme.textMuted)),
                    );
                  }

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primary.withOpacity(0.12),
                                child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.description ?? "No description provided",
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: product.active
                                      ? AppTheme.success.withOpacity(0.12)
                                      : AppTheme.textMuted.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  product.active ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    color: product.active ? AppTheme.success : AppTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showProductForm(product: product);
                                  } else if (val == 'delete') {
                                    _confirmDeleteProduct(product);
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
