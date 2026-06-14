import 'package:sqflite/sqflite.dart';
import 'package:client_flutter/core/api_client.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/features/products/models/product_model.dart';

class ProductsRepository {
  final ApiClient apiClient;

  ProductsRepository(this.apiClient);

  Future<List<ProductModel>> getProducts() async {
    try {
      final response = await apiClient.get('/products');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final products = data.map((json) => ProductModel.fromJson(json as Map<String, dynamic>)).toList();

        // Update cache
        final db = await DbHelper.database;
        await db.transaction((txn) async {
          await txn.delete('products');
          for (var product in products) {
            await txn.insert(
              'products',
              product.toJson(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        return products;
      }
    } catch (e) {
      print("Products fetch error, loading from local cache: $e");
    }

    // Fallback to SQLite cache
    return await _getCachedProducts();
  }

  Future<List<ProductModel>> _getCachedProducts() async {
    final db = await DbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return maps.map((json) => ProductModel.fromJson(json)).toList();
  }
}
