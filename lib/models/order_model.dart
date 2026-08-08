num _asNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

// ── Embedded product snapshot returned by formatOrder() ──────────────────────
// Backend inarudisha:
//   "product": { "id", "product_name", "price", "image_url" }
class OrderProductSnapshot {
  final int id;
  final String productName;
  final double price;
  final String? imageUrl; // Full URL (resolved by backend resolveImageUrl)

  const OrderProductSnapshot({
    required this.id,
    required this.productName,
    required this.price,
    this.imageUrl,
  });

  factory OrderProductSnapshot.fromJson(Map<String, dynamic> json) {
    return OrderProductSnapshot(
      id: _asNum(json['id']).toInt(),
      productName: (json['product_name'] ?? json['name'] ?? '').toString(),
      price: _asNum(json['price']).toDouble(),
      imageUrl: json['image_url'] as String?,
    );
  }
}

// ── OrderStatus ───────────────────────────────────────────────────────────────
// Backend controller inaruhusu seller ku-update tu:
//   processing | shipped | completed | cancelled
// Status nyingine zinatoka kwa mfumo/WhatsApp — zinaonyeshwa tu (read-only).
enum OrderStatus {
  pendingConfirmation, // pending_seller_confirmation / pending
  pendingPayment,      // confirmed / pending_payment / paid
  processing,
  shipped,
  completed,
  cancelled,
  rejected,
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pendingConfirmation:
        return 'Inasubiri Uthibitisho';
      case OrderStatus.pendingPayment:
        return 'Inasubiri Malipo';
      case OrderStatus.processing:
        return 'Inachakatwa';
      case OrderStatus.shipped:
        return 'Imesafirishwa';
      case OrderStatus.completed:
        return 'Imekamilika';
      case OrderStatus.cancelled:
        return 'Imefutwa';
      case OrderStatus.rejected:
        return 'Imekataliwa';
    }
  }

  String get color {
    switch (this) {
      case OrderStatus.pendingConfirmation:
        return '#FFB300';
      case OrderStatus.pendingPayment:
        return '#FF9800';
      case OrderStatus.processing:
        return '#2196F3';
      case OrderStatus.shipped:
        return '#9C27B0';
      case OrderStatus.completed:
        return '#4CAF50';
      case OrderStatus.cancelled:
        return '#F44336';
      case OrderStatus.rejected:
        return '#795548';
    }
  }

  static OrderStatus fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
      case 'pending_seller_confirmation':
        return OrderStatus.pendingConfirmation;
      case 'confirmed':
      case 'pending_payment':
      case 'paid':
        return OrderStatus.pendingPayment;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'completed':
      case 'delivered':
        return OrderStatus.completed;
      case 'rejected':
      case 'cancelled_by_seller':
        return OrderStatus.rejected;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pendingConfirmation;
    }
  }
}

// ── OrderModel ────────────────────────────────────────────────────────────────
// Inaakisi formatOrder() kutoka Laravel:
//   id, order_number, status, buyer_phone, delivery_address,
//   total_amount (= product_price tu, bila service_fee — seller haoni ada),
//   created_at, updated_at,
//   product: { id, product_name, price, image_url }
//
// NOTE: Backend ilitoa 'service_fee' na 'product_price' kwa sababu za
// usalama (seller hapaswi kuona ada ya huduma). Sasa 'total_amount'
// kwenye response ni product_price pekee.
class OrderModel {
  final int id;
  final String orderNumber;
  final OrderStatus status;
  final String buyerPhone;
  final String deliveryAddress;
  final double totalAmount; // = product_price kutoka backend (bila service_fee)
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderProductSnapshot? product;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.buyerPhone,
    required this.deliveryAddress,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.product,
  });

  String get formattedTotal => 'TZS ${totalAmount.toStringAsFixed(0)}';

  bool get isCompleted => status == OrderStatus.completed;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final productData = json['product'] as Map<String, dynamic>?;

    return OrderModel(
      id: _asNum(json['id']).toInt(),
      orderNumber: (json['order_number'] ?? '#${json['id']}').toString(),
      status: OrderStatusExtension.fromApiValue(
        (json['status'] ?? 'pending').toString(),
      ),
      buyerPhone: (json['buyer_phone'] ?? '').toString(),
      deliveryAddress: (json['delivery_address'] ?? '').toString(),
      totalAmount: _asNum(json['total_amount']).toDouble(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      product: productData != null
          ? OrderProductSnapshot.fromJson(productData)
          : null,
    );
  }

  OrderModel copyWith({OrderStatus? status}) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      status: status ?? this.status,
      buyerPhone: buyerPhone,
      deliveryAddress: deliveryAddress,
      totalAmount: totalAmount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      product: product,
    );
  }
}