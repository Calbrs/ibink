// ============================================================
// tiktok_webview_screen.dart
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api_config.dart';
import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/notification_modals.dart';

class TikTokWebViewScreen extends StatefulWidget {
  final String url;

  const TikTokWebViewScreen({super.key, required this.url});

  @override
  State<TikTokWebViewScreen> createState() => _TikTokWebViewScreenState();
}

class _TikTokWebViewScreenState extends State<TikTokWebViewScreen> {
  static const String _tag = 'TikTokWebView';

  late final WebViewController _controller;
  Timer? _stallTimer;

  bool _handled = false;
  bool _isLoading = true;
  double _progress = 0;

  static const Duration _maxDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();

    AppLogger.instance
        .info(_tag, 'Opening authorize URL (len=${widget.url.length}).');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
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
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

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

    if (ApiConfig.isTikTokCallbackUrl(url)) {
      AppLogger.instance.info(_tag, 'Callback navigation intercepted.');
      _completeCallback(url);
      return NavigationDecision.prevent;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      AppLogger.instance.warn(_tag, 'Blocked non-http scheme: $url');
      return NavigationDecision.prevent;
    }

    AppLogger.instance.debug(_tag, 'Navigate: $url');
    return NavigationDecision.navigate;
  }

  void _onStalled() {
    if (!mounted || _handled) return;
    _handled = true;
    AppLogger.instance.error(
      _tag,
      'Timed out after ${_maxDuration.inMinutes}min without a callback redirect.',
    );
    NotificationService.showErrorBanner(
      context,
      message: 'Muda wa kuunganisha TikTok umeisha. Jaribu tena.',
    );
    context.pop();
  }

  void _completeCallback(String url) {
    if (_handled) return;
    _handled = true;
    _stallTimer?.cancel();

    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    AppLogger.instance.info(
      _tag,
      'Callback params — code=${code != null ? "present(${code.length})" : "absent"} '
      'state=${state != null ? "present(${state.length})" : "absent"} '
      'error=${error ?? "none"}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (error != null) {
        AppLogger.instance.warn(_tag, 'TikTok returned OAuth error: $error');
        NotificationService.showErrorBanner(
          context,
          message: _errorMessageFor(error),
        );
        context.pop();
        return;
      }

      if (code == null || code.isEmpty || state == null || state.isEmpty) {
        AppLogger.instance.error(_tag, 'Callback missing code or state.');
        NotificationService.showErrorBanner(
          context,
          message: 'Kodi ya uthibitisho haipatikani. Jaribu tena.',
        );
        context.pop();
        return;
      }

      AppLogger.instance.info(_tag, 'Handing off to callback screen.');

      context.pushReplacement(
        AppRoutes.tiktokCallback,
        extra: {'code': code, 'state': state},
      );
    });
  }

  String _errorMessageFor(String error) {
    switch (error) {
      case 'access_denied':
        return 'Umekghairi kuingia kwenye TikTok.';
      case 'invalid_request':
        return 'Ombi la kuingia si sahihi. Jaribu tena.';
      case 'server_error':
        return 'TikTok haipatikani kwa sasa. Jaribu tena baadaye.';
      default:
        return 'TikTok haikukamilisha uthibitisho. Jaribu tena.';
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text(
            'Unganisha TikTok',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          backgroundColor: AppColors.bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.ink),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
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
                backgroundColor: AppColors.line,
                color: AppColors.green,
              ),
            const _TikTokHint(),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}

class _TikTokHint extends StatelessWidget {
  const _TikTokHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.green),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Ingia kwenye TikTok kisha bonyeza "Authorize" kuruhusu ONBAIO.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}