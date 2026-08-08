import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://ibink.me/api';

  static const String sendWhatsAppOtpEndpoint = '/auth/send-whatsapp-otp';
  static const String verifyWhatsAppOtpEndpoint = '/auth/verify-whatsapp-otp';
  static const String completeProfileEndpoint = '/user/complete-profile';

  static const String userProfileEndpoint = '/user/profile';
  static const String sellerProfileEndpoint = '/seller/profile';
  static const String productsEndpoint = '/products';
  static const String ordersEndpoint = '/seller/orders';
  static const String ordersSummaryEndpoint = '/seller/orders-summary';
  static const String storeBySlugEndpoint = '/store';
  static const String checkoutEndpoint = '/checkout';
  static const String salesBatchEndpoint = '/seller/sales/batch';

  /// GET /seller/sales/summary?range=week|month|year
  static const String revenueSummaryEndpoint = '/seller/sales/summary';

  /// GET /seller/sales?range=...&per_page=50
  static const String salesHistoryEndpoint = '/seller/sales';

  /// GET /api/seller/orders/{id}
  static String orderDetailEndpoint(String orderId) => '/seller/orders/$orderId';

  /// PATCH /api/seller/orders/{id}/status
  static String orderStatusEndpoint(String orderId) => '/seller/orders/$orderId/status';

  /// DELETE /api/seller/orders/{id}
  static String orderDeleteEndpoint(String orderId) => '/seller/orders/$orderId';

  static String get _host {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  static String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$_host$normalized';
  }

  static const String phoneTokenHeader = 'X-Phone-Token'; // kept for compatibility

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}