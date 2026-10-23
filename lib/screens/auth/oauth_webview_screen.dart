// ============================================================
// oauth_webview_screen.dart
// Google/Apple Socialite flow inside an in-app WebView.
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api_config.dart';
import '../../core/app_logger.dart';
import 'auth_screen.dart';

/// Google / Apple — the chooser for [OAuthWebViewScreen].
enum OAuthProvider { google, apple }

/// Login tab → `intent=login` (existing sellers only).
/// Register tab → `intent=register` (new users only).
enum OAuthIntent { login, register }

/// What the WebView hands back to the auth flow after intercepting the
/// frontend redirect: a handoff token with its landing kind.
class OAuthResult {
  /// True when the landing was `/authenticator` (a two-factor challenge
  /// token for an existing seller); false when it was `/verify-otp` (an
  /// email-code draft token for a new social registration).
  final bool isLogin;
  final String token;

  /// 'google' | 'apple' — selects the verify/resend endpoints.
  final String provider;

  const OAuthResult({
    required this.isLogin,
    required this.token,
    required this.provider,
  });
}

/// Opens `{base}/auth/{provider}/redirect?intent=...` in a WebView. Once the
/// backend callback redirects the browser to the frontend SPA, the landing
/// URL is intercepted and popped back as an [OAuthResult] (or an error
/// notice) — exactly the TikTok connect pattern.
class OAuthWebViewScreen extends StatefulWidget {
  final OAuthProvider provider;
  final OAuthIntent intent;

  const OAuthWebViewScreen({
    super.key,
    required this.provider,
    required this.intent,
  });

  /// Pushes the flow fullscreen. Returns the handoff, or null when the user
  /// backs out / the flow fails (an error banner shows the reason first).
  static Future<OAuthResult?> show(
    BuildContext context, {
    required OAuthProvider provider,
    required OAuthIntent intent,
  }) {
    return Navigator.of(context, rootNavigator: true).push<OAuthResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OAuthWebViewScreen(provider: provider, intent: intent),
      ),
    );
  }

  String get _label => provider == OAuthProvider.google ? 'Google' : 'Apple';

  String get _startUrl {
    final endpoint = provider == OAuthProvider.google
        ? ApiConfig.googleRedirectEndpoint
        : ApiConfig.appleRedirectEndpoint;
    final intent = this.intent == OAuthIntent.register ? 'register' : 'login';
    return '${ApiConfig.baseUrl}$endpoint?intent=$intent';
  }

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  static const String _tag = 'OAuthWebView';

  late final WebViewController _controller;
  Timer? _stallTimer;

  bool _handled = false;
  bool _isLoading = true;
  double _progress = 0;

  static const Duration _maxDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();

    AppLogger.instance.info(
      _tag,
      'Opening ${widget._label} authorize URL (intent=${widget.intent.name}).',
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageStarted: (url) {
            AppLogger.instance.info(_tag, 'Page started: $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            AppLogger.instance.info(_tag, 'Page finished: $url');
            if (mounted) setState(() => _isLoading = false);
          },
          onHttpError: _onHttpError,
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(widget._startUrl));

    _stallTimer = Timer(_maxDuration, _onStalled);
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _stallTimer = null;
    super.dispose();
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;
    final handoff = ApiConfig.socialHandoffKind(url);

    if (handoff != SocialHandoff.none) {
      AppLogger.instance.info(
        _tag,
        'Handoff navigation intercepted ($handoff).',
      );
      _completeWith(url);
      return NavigationDecision.prevent;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      AppLogger.instance.warn(_tag, 'Blocked non-http scheme: $url');
      return NavigationDecision.prevent;
    }

    AppLogger.instance.debug(_tag, 'Navigate: $url');
    return NavigationDecision.navigate;
  }

  /// Fail fast when the backend itself errors (e.g. Apple's Socialite
  /// config is not live yet) instead of waiting out the stall timer.
  void _onHttpError(HttpResponseError error) {
    if (_handled) return;
    final status = error.response?.statusCode ?? 0;
    if (status < 500) return; // harmless during the redirect hops

    final host = Uri.tryParse(error.request?.uri.toString() ?? '')?.host;
    final apiHost = Uri.tryParse(ApiConfig.baseUrl)?.host;
    if (host == null || apiHost == null || host != apiHost) return;

    AppLogger.instance.error(_tag, 'Backend error $status during OAuth flow.');
    _abort('${widget._label} haipatikani kwa sasa. Jaribu tena baadaye.');
  }

  void _onStalled() {
    if (!mounted || _handled) return;
    _handled = true;
    AppLogger.instance.error(
      _tag,
      'Timed out after ${_maxDuration.inMinutes}min without a frontend redirect.',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Muda wa uthibitisho umeisha. Jaribu tena.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AuthColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  void _completeWith(String url) {
    if (_handled) return;
    _handled = true;
    _stallTimer?.cancel();

    final uri = Uri.parse(url);
    final token = uri.queryParameters['token'] ?? '';
    final error = uri.queryParameters['error'];
    final isLogin = uri.path.toLowerCase().contains('authenticator');

    AppLogger.instance.info(
      _tag,
      'Handoff — login=$isLogin token=${token.isEmpty ? "absent" : "present(${token.length})"} '
      'error=${error ?? "none"}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (token.isEmpty) {
        _abort(_errorText(error));
        return;
      }

      Navigator.of(context).pop(
        OAuthResult(
          isLogin: isLogin,
          token: token,
          provider: widget.provider == OAuthProvider.google
              ? 'google'
              : 'apple',
        ),
      );
    });
  }

  /// Shows the failure banner and pops with no result.
  void _abort(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AuthColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    Navigator.of(context).pop();
  }

  /// Swahili notices for the backend's `error=` codes (GoogleAuthController).
  String _errorText(String? error) {
    const label = 'Google/Apple'; // refined per provider below
    switch (error) {
      case 'google_state':
      case 'google_failed':
      case 'apple_state':
      case 'apple_failed':
        return 'Kuingia kwa ${widget._label} hakukamilika. Jaribu tena.';
      case 'google_email_unverified':
      case 'apple_email_unverified':
        return 'Barua pepe yako haijathibitishwa. Tumia njia nyingine.';
      case 'no_account':
        return 'Akaunti haipo. Tafadhali jisajili kwanza.';
      case 'account_exists':
        return 'Akaunti hii tayari ipo. Tafadhali ingia (login).';
      case 'google_conflict':
      case 'apple_conflict':
        return 'Akaunti hii imeunganishwa na ${widget._label} nyingine.';
      case 'account_blocked':
        return 'Akaunti yako imesimamishwa.';
      default:
        if (error != null && error.startsWith('register_')) {
          switch (error.substring('register_'.length)) {
            case 'email_taken':
            case 'exists':
              return 'Email hii tayari imesajiliwa. Tafadhali ingia (login).';
            case 'locked':
              return 'Umejaribu mara nyingi. Tafadhali anza usajili upya.';
            case 'cooldown':
              return 'Subiri kidogo kisha jaribu tena.';
            case 'expired':
              return 'Muda wa usajili umeisha. Tafadhali anza upya.';
            default:
              return 'Imeshindikana kutuma email. Tafadhali jaribu tena.';
          }
        }
        return 'Kuingia kwa $label hakukamilika. Jaribu tena.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _stallTimer?.cancel();
      },
      child: Scaffold(
        backgroundColor: AuthColors.paper,
        appBar: AppBar(
          title: Text(
            widget._label == 'Google'
                ? 'Endelea na Google'
                : 'Endelea na Apple',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AuthColors.ink,
            ),
          ),
          backgroundColor: AuthColors.paper,
          elevation: 0,
          iconTheme: const IconThemeData(color: AuthColors.ink),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AuthColors.ink),
              onPressed: () {
                _stallTimer?.cancel();
                _stallTimer = Timer(_maxDuration, _onStalled);
                _controller.reload();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2,
                backgroundColor: AuthColors.line,
                color: AuthColors.gold,
              ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
