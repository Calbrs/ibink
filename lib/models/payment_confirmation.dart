num _asNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

enum PaymentProvider {
  mpesa,
  tigopesa,
  airtelmoney,
  bank,
  other,
}

extension PaymentProviderExtension on PaymentProvider {
  String get label {
    switch (this) {
      case PaymentProvider.mpesa:
        return 'M-Pesa';
      case PaymentProvider.tigopesa:
        return 'TigoPesa';
      case PaymentProvider.airtelmoney:
        return 'Airtel Money';
      case PaymentProvider.bank:
        return 'Benki';
      case PaymentProvider.other:
        return 'Nyingine';
    }
  }

  String get apiValue => name;

  static PaymentProvider fromApiValue(String value) {
    return PaymentProvider.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PaymentProvider.other,
    );
  }
}

enum PaymentConfirmationStatus {
  pending,
  confirmed,
  rejected,
}

extension PaymentConfirmationStatusExtension on PaymentConfirmationStatus {
  String get label {
    switch (this) {
      case PaymentConfirmationStatus.pending:
        return 'Inasubiri';
      case PaymentConfirmationStatus.confirmed:
        return 'Imethibitishwa';
      case PaymentConfirmationStatus.rejected:
        return 'Imekataliwa';
    }
  }

  String get apiValue => name;

  static PaymentConfirmationStatus fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'confirmed':
        return PaymentConfirmationStatus.confirmed;
      case 'rejected':
        return PaymentConfirmationStatus.rejected;
      default:
        return PaymentConfirmationStatus.pending;
    }
  }
}

class PaymentConfirmation {
  final int id;
  final int orderId;
  final String orderNumber;
  final String buyerPhone;
  final double amount;
  final PaymentProvider provider;
  final String? senderName;
  final String? senderPhone;
  final String? reference;
  final String? screenshotPath;
  final String? screenshotUrl;
  final String? ocrRawText;
  final double? confidenceScore;
  final PaymentConfirmationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentConfirmation({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.buyerPhone,
    required this.amount,
    required this.provider,
    this.senderName,
    this.senderPhone,
    this.reference,
    this.screenshotPath,
    this.screenshotUrl,
    this.ocrRawText,
    this.confidenceScore,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  String get formattedAmount => 'TZS ${amount.toStringAsFixed(0)}';

  bool get isPending => status == PaymentConfirmationStatus.pending;

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) {
    return PaymentConfirmation(
      id: _asNum(json['id']).toInt(),
      orderId: _asNum(json['order_id']).toInt(),
      orderNumber: (json['order_number'] ?? '#${json['order_id']}').toString(),
      buyerPhone: (json['buyer_phone'] ?? '').toString(),
      amount: _asNum(json['amount']).toDouble(),
      provider: PaymentProviderExtension.fromApiValue(
        (json['provider'] ?? 'other').toString(),
      ),
      senderName: json['sender_name'] as String?,
      senderPhone: json['sender_phone'] as String?,
      reference: json['reference'] as String?,
      screenshotPath: json['screenshot_path'] as String?,
      screenshotUrl: json['screenshot_url'] as String?,
      ocrRawText: json['ocr_raw_text'] as String?,
      confidenceScore: json['confidence_score'] != null
          ? _asNum(json['confidence_score']).toDouble()
          : null,
      status: PaymentConfirmationStatusExtension.fromApiValue(
        (json['status'] ?? 'pending').toString(),
      ),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
