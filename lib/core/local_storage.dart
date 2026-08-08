import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../models/product_model.dart';

class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  static const String _boxProducts = 'products_box';
  static const String _boxPendingSales = 'pending_sales_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_boxProducts);
    await Hive.openBox<String>(_boxPendingSales);
  }

  // --- Products Cache ---

  Future<void> saveProducts(List<ProductModel> products) async {
    final box = Hive.box<String>(_boxProducts);
    final List<Map<String, dynamic>> jsonList = products.map((p) => p.toJson()).toList();
    await box.put('all_products', jsonEncode(jsonList));
  }

  List<ProductModel> getCachedProducts() {
    final box = Hive.box<String>(_boxProducts);
    final String? data = box.get('all_products');
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => ProductModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Pending Sales (Offline) ---

  Future<void> addPendingSale(Map<String, dynamic> sale) async {
    final box = Hive.box<String>(_boxPendingSales);
    final sales = getPendingSales();
    sales.add(sale);
    await box.put('sales', jsonEncode(sales));
  }

  Future<void> savePendingSales(List<Map<String, dynamic>> sales) async {
    final box = Hive.box<String>(_boxPendingSales);
    await box.put('sales', jsonEncode(sales));
  }

  List<Map<String, dynamic>> getPendingSales() {
    final box = Hive.box<String>(_boxPendingSales);
    final String? data = box.get('sales');
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearPendingSales() async {
    final box = Hive.box<String>(_boxPendingSales);
    await box.delete('sales');
  }
}
