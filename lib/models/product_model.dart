import 'package:flutter/material.dart';
import '../core/api_config.dart';
import '../core/theme.dart';

enum StockStatus {
  ok('In stock', AppColors.green),
  low('Low stock', AppColors.amber),
  out('Out of stock', AppColors.ink);

  final String label;
  final Color color;
  const StockStatus(this.label, this.color);
}

class ProductModel {
  final int id;
  final String name;
  final double price;
  final int quantity;
  final String description;
  final String? category;
  final String? imageUrl;
  final String? imagePath;
  final String status; // 'active' | 'inactive' | 'draft' - kutoka kwa backend
  final String? barcode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.description,
    this.category,
    this.imageUrl,
    this.imagePath,
    this.status = 'active',
    this.barcode,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedPrice => 'TZS ${price.toStringAsFixed(0)}';

  bool get visible => status == 'active';

  StockStatus get stockStatus {
    if (quantity == 0) return StockStatus.out;
    if (quantity <= 10) return StockStatus.low;
    return StockStatus.ok;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      // Backend (Laravel ProductController) inarudisha "product_name", sio "name".
      name: json['product_name'] ?? json['name'] ?? '',
      price: double.tryParse('${json['price'] ?? 0}') ?? 0,
      // Backend inatumia column "stock", sio "quantity".
      quantity: json['stock'] is int
          ? json['stock']
          : int.tryParse('${json['stock'] ?? json['quantity'] ?? 0}') ?? 0,
      description: json['description'] ?? '',
      category: json['category'],
      // image_url inayorudi kutoka backend ni njia ya jamaa (relative), hivyo
      // tunaijenga kuwa URL kamili ili NetworkImage iweze kuipakia.
      imageUrl: ApiConfig.resolveImageUrl(json['image_url'] as String?),
      imagePath: json['image_path'],
      status: json['status'] ?? 'active',
      barcode: json['barcode'],
      // Laravel timestamps huja kama ISO 8601 strings (mfano
      // "2026-07-14T10:30:00.000000Z"). DateTime.tryParse inashughulikia
      // muundo huo moja kwa moja; tunarudisha null kama haipo/si sahihi
      // badala ya kutupa exception.
      createdAt: json['created_at'] != null ? DateTime.tryParse('${json['created_at']}')?.toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse('${json['updated_at']}')?.toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_name': name,
        'price': price,
        'stock': quantity,
        'description': description,
        'category': category,
        'image_url': imageUrl,
        'image_path': imagePath,
        'status': status,
        'barcode': barcode,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  ProductModel copyWith({
    int? id,
    String? name,
    double? price,
    int? quantity,
    String? description,
    String? category,
    String? imageUrl,
    String? imagePath,
    String? status,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}