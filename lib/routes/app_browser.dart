import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

/// Generic in-app browser.
///
/// Used for read-only browsing (Instagram, Facebook, a TikTok profile page).
/// It deliberately does NOT intercept navigation or sniff OAuth params — the
/// TikTok connect flow lives in TikTokWebViewScreen so that its callback
/// handling stays isolated from everything else that opens a WebView.
class AppBrowserScreen extends StatefulWidget {
  final String url;
  final String title;

  const AppBrowserScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<AppBrowserScreen> createState() => _AppBrowserScreenState();
}

class _AppBrowserScreenState extends State<AppBrowserScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 2.5,
              backgroundColor: AppColors.line,
              color: AppColors.green,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}