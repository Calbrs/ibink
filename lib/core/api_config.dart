import 'package:flutter_dotenv/flutter_dotenv.dart';

/// What a frontend URL means for the OAuth handoff: [none] = keep
/// browsing, [success] / [error] = pop the WebView and continue in-app.
enum SocialHandoff { none, success, error }

class ApiConfig {
  ApiConfig._();

  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://onbaio.com/api';

  // ── Auth (onbaio.com) ───────────────────────────────────────────────
  // The base URL already contains /api, so endpoints below are appended
  // verbatim, e.g. https://onbaio.com/api/auth/login.

  /// POST /auth/login — body `{phone_number: "+2557xxxxxxxx"}`.
  /// 200 → `{two_factor_required: true, two_factor_token: "..."}`.
  /// 404 → `{action: "register"}` — account does not exist yet.
  static const String loginEndpoint = '/auth/login';

  /// POST /auth/register — body `{first_name, middle_name?, last_name, email}`.
  /// 201 → `{token, retry_after, expires_in}` — token identifies the
  /// registration draft until the email code is verified.
  static const String registerEndpoint = '/auth/register';

  /// POST /auth/register/verify — body `{token, code: 6 digits}`.
  static const String registerVerifyEndpoint = '/auth/register/verify';

  /// POST /auth/register/resend — body `{token}`.
  static const String registerResendEndpoint = '/auth/register/resend';

  /// POST /auth/two-factor/send-code — body `{token}` (the two_factor_token).
  static const String twoFactorSendCodeEndpoint = '/auth/two-factor/send-code';

  /// POST /auth/two-factor/challenge — body `{token, code: 6 digits}`.
  static const String twoFactorChallengeEndpoint = '/auth/two-factor/challenge';

  /// POST /auth/two-factor/status — body `{token}`.
  static const String twoFactorStatusEndpoint = '/auth/two-factor/status';

  // ── Social OAuth (Google/Apple — Socialite, in-browser) ─────────────
  //
  // The consent flow runs inside an in-app WebView: GET
  // /auth/{provider}/redirect?intent=login|register starts it, the backend
  // callback then redirects the browser to the frontend SPA and the app
  // intercepts that landing (see OAuthWebViewScreen):
  //
  //   login  intent, existing seller → {frontendUrl}/authenticator?token=<challenge>
  //   register intent, new user      → {frontendUrl}/verify-otp?provider=<p>&token=<draft>
  //   everything else (failures)     → {frontendUrl}/login|register?error=<code>
  //
  // Register drafts verify via POST /auth/{provider}/verify and resend via
  // POST /auth/{provider}/resend ({token, code: 6 digits}).

  /// Frontend SPA the OAuth callback redirects to. Override with FRONTEND_URL.
  static String get frontendUrl =>
      dotenv.env['FRONTEND_URL'] ?? 'https://onbaio.com';

  static const String googleRedirectEndpoint = '/auth/google/redirect';
  static const String googleVerifyEndpoint = '/auth/google/verify';
  static const String googleResendEndpoint = '/auth/google/resend';

  static const String appleRedirectEndpoint = '/auth/apple/redirect';
  static const String appleVerifyEndpoint = '/auth/apple/verify';
  static const String appleResendEndpoint = '/auth/apple/resend';

  /// Where the backend sent the browser after the OAuth callback:
  /// - [SocialHandoff.success] with the handoff `token` for the
  ///   `/authenticator` and `/verify-otp` landings,
  /// - [SocialHandoff.error] for the `/login` + `/register` failure
  ///   redirects,
  /// - [SocialHandoff.none] when [url] is not a frontend handoff page.
  static SocialHandoff socialHandoffKind(String? url) {
    if (url == null || url.isEmpty) return SocialHandoff.none;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return SocialHandoff.none;

    final frontend = Uri.tryParse(frontendUrl);
    final targetHost = frontend?.host.toLowerCase();
    if (targetHost == null || targetHost.isEmpty) return SocialHandoff.none;

    final host = uri.host.toLowerCase();
    if (host != targetHost && host != 'www.$targetHost') {
      return SocialHandoff.none;
    }

    final path = _normalizePath(uri.path);
    switch (path) {
      case '/authenticator': // existing seller → two-factor challenge
      case '/verify-otp': // new user → email code for the social draft
        return (uri.queryParameters['token'] ?? '').isEmpty
            ? SocialHandoff.error
            : SocialHandoff.success;
      case '/login': // failure redirects from the backend
      case '/register':
        return SocialHandoff.error;
      default:
        return SocialHandoff.none;
    }
  }

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

  // ── TikTok Integration ──────────────────────────────────────────────
  static const String tiktokAuthUrlEndpoint = '/tiktok/auth/url';
  static const String tiktokCallbackEndpoint = '/tiktok/callback';
  static const String tiktokProfileEndpoint = '/tiktok/profile';
  static const String tiktokVideosEndpoint = '/tiktok/videos';
  static const String tiktokDisconnectEndpoint = '/tiktok/disconnect';
  static const String tiktokSyncEndpoint = '/tiktok/sync';

  // ── Distribution (single entry point for product + TikTok) ─────────
  //
  // POST /distribute creates the product and, when a `video` file is included
  // and `platforms[]` contains tiktok, publishes it in the same request.
  // Without a video it is simply a product create.

  /// POST /distribute (multipart)
  static const String distributeEndpoint = '/distribute';

  /// POST /distribute/status — body `{"publish_id": "..."}`.
  static const String distributeStatusEndpoint = '/distribute/status';

  /// GET /tiktok/publish/creator-info — what the linked account allows:
  /// privacy options and which interactions the creator has switched off.
  static const String tiktokCreatorInfoEndpoint =
      '/tiktok/publish/creator-info';

  // ── Payment Reconciliation ──────────────────────────────────────────
  static const String paymentConfirmationsEndpoint = '/payments/confirmations';

  /// POST /payments/confirmations/{id}/confirm|reject
  static String paymentConfirmActionEndpoint(String id) =>
      '/payments/confirmations/$id';

  /// GET /api/seller/orders/{id}
  static String orderDetailEndpoint(String orderId) =>
      '/seller/orders/$orderId';

  /// PATCH /api/seller/orders/{id}/status
  static String orderStatusEndpoint(String orderId) =>
      '/seller/orders/$orderId/status';

  /// DELETE /api/seller/orders/{id}
  static String orderDeleteEndpoint(String orderId) =>
      '/seller/orders/$orderId';

  // ── TikTok OAuth callback detection ─────────────────────────────────
  //
  // The redirect_uri the backend registered with TikTok is the single source
  // of truth. It is read from .env (TIKTOK_REDIRECT_URI) instead of being
  // hardcoded so that changing the backend never silently breaks the app.
  static String get tiktokRedirectUri =>
      dotenv.env['TIKTOK_REDIRECT_URI'] ?? 'https://zumimo.com/tiktok/callback';

  /// Fallback redirect URIs. The value in .env wins, but these are accepted as
  /// well so a mismatch between the app build and the backend config degrades
  /// into "still works" rather than "OAuth silently hangs".
  static const List<String> tiktokRedirectUriFallbacks = [
    'https://zumimo.com/tiktok/callback',
    'https://api.zumimo.com/auth/callback/tiktok',
    'https://ibink.me/api/auth/callback/tiktok',
    'ibink://tiktok/callback',
  ];

  static List<Uri> get _tiktokCallbackUris {
    final all = <String>[tiktokRedirectUri, ...tiktokRedirectUriFallbacks];
    final parsed = <Uri>[];
    for (final value in all) {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          !parsed.any((e) => e.host == uri.host && e.path == uri.path)) {
        parsed.add(uri);
      }
    }
    return parsed;
  }

  /// Whether [url] is one of the TikTok OAuth callback URIs.
  ///
  /// Compares scheme + host + path only. Query params (`code`, `state`) are
  /// ignored on purpose, and the comparison is case-insensitive so that a
  /// trailing slash or capitalised host cannot make us miss the callback.
  static bool isTikTokCallbackUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final target = Uri.tryParse(url);
    if (target == null) return false;
    if (target.host.isEmpty) return false;

    for (final candidate in _tiktokCallbackUris) {
      if (candidate.host.toLowerCase() != target.host.toLowerCase()) continue;
      final a = _normalizePath(candidate.path);
      final b = _normalizePath(target.path);
      if (a == b) return true;
    }
    return false;
  }

  static String _normalizePath(String path) {
    final trimmed = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    return trimmed.toLowerCase();
  }

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

  static const String phoneTokenHeader =
      'X-Phone-Token'; // kept for compatibility

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static String? get apiSecretKey {
    final key = dotenv.env['API_SECRET_KEY'];
    return (key == null || key.isEmpty) ? null : key;
  }

  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-API-KEY': ?apiSecretKey,
  };

  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
}
