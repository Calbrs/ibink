import '../models/payment_confirmation.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'app_logger.dart';

const String _tag = 'Payments';

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  /// Fetch payment confirmations, optionally filtered by status.
  Future<List<PaymentConfirmation>> fetchConfirmations({
    PaymentConfirmationStatus? status,
  }) async {
    final query = status != null ? '?status=${status.apiValue}' : '';
    final response = await ApiClient.instance.get(
      '${ApiConfig.paymentConfirmationsEndpoint}$query',
    );

    if (!response.success) {
      AppLogger.instance.warn(_tag, 'fetchConfirmations failed: ${response.error}');
      return [];
    }

    final payload = response.data?['data'];
    final rawList = payload is Map<String, dynamic>
        ? (payload['data'] as List? ?? [])
        : (payload as List? ?? []);

    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => PaymentConfirmation.fromJson(e))
        .toList();

    AppLogger.instance.info(
      _tag,
      'Fetched ${items.length} confirmation(s) filter=${status?.apiValue ?? 'all'}',
    );
    return items;
  }

  /// Submit a payment confirmation with optional screenshot.
  /// The screenshot is uploaded as a multipart file via ApiClient.postMultipart.
  Future<PaymentConfirmation?> submitConfirmation({
    required int orderId,
    required double amount,
    required String provider,
    String? senderName,
    String? senderPhone,
    String? reference,
    String? screenshotPath,
  }) async {
    final fields = <String, String>{
      'order_id': orderId.toString(),
      'amount': amount.toString(),
      'provider': provider,
      'sender_name': ?senderName,
      'sender_phone': ?senderPhone,
      'reference': ?reference,
    };

    AppLogger.instance.info(
      _tag,
      'Submitting confirmation for order $orderId, amount=$amount, '
      'provider=$provider, hasScreenshot=${screenshotPath != null}',
    );

    final response = await ApiClient.instance.postMultipart(
      ApiConfig.paymentConfirmationsEndpoint,
      fields,
      screenshotPath,
      'screenshot',
    );

    if (!response.success || response.data == null) {
      AppLogger.instance.warn(_tag, 'submitConfirmation failed: ${response.error}');
      return null;
    }

    final data = response.data!['data'];
    if (data is Map<String, dynamic>) {
      AppLogger.instance.info(_tag, 'Confirmation $orderId submitted.');
      return PaymentConfirmation.fromJson(data);
    }
    AppLogger.instance.warn(_tag, 'submitConfirmation: response missing data object.');
    return null;
  }

  /// Confirm a payment confirmation (mark as confirmed).
  Future<bool> confirmPayment(int confirmationId) async {
    final response = await ApiClient.instance.post(
      ApiConfig.paymentConfirmActionEndpoint(confirmationId.toString()),
      {'action': 'confirm'},
    );
    if (!response.success) {
      AppLogger.instance.warn(_tag, 'confirmPayment($confirmationId) failed: ${response.error}');
    }
    return response.success;
  }

  /// Reject a payment confirmation (mark as rejected).
  Future<bool> rejectPayment(int confirmationId) async {
    final response = await ApiClient.instance.post(
      ApiConfig.paymentConfirmActionEndpoint(confirmationId.toString()),
      {'action': 'reject'},
    );
    if (!response.success) {
      AppLogger.instance.warn(_tag, 'rejectPayment($confirmationId) failed: ${response.error}');
    }
    return response.success;
  }

  /// Count pending confirmations (for dashboard badge).
  Future<int> countPending() async {
    final response = await ApiClient.instance.get(
      '${ApiConfig.paymentConfirmationsEndpoint}?status=pending',
    );

    if (!response.success) return 0;

    final payload = response.data?['data'];
    if (payload is Map<String, dynamic>) {
      final total = payload['total'];
      if (total is num) return total.toInt();
      return (payload['data'] as List?)?.length ?? 0;
    }
    if (payload is List) return payload.length;
    return 0;
  }
}
