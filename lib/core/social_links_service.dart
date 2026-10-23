import 'package:flutter/foundation.dart';

import '../models/social_account_model.dart';
import 'app_logger.dart';
import 'tiktok_service.dart';

const String _tag = 'SocialLinks';

/// One row in the "link account" sheet.
class SocialLinkState {
  final SocialPlatform platform;

  /// True when the seller has actually linked this platform. Today only TikTok
  /// has a real connection behind it — the others fall back to opening the
  /// site, so they must keep reporting false or the UI would claim a link that
  /// does not exist.
  final bool isConnected;

  /// Handle of the linked account, when known.
  final String? handle;

  /// True when a linked account has its own in-app page to visit. Platforms
  /// without one fall back to opening the website.
  final bool hasLinkedPage;

  const SocialLinkState({
    required this.platform,
    required this.isConnected,
    this.handle,
    required this.hasLinkedPage,
  });

  String? get subtitle =>
      (handle != null && handle!.isNotEmpty) ? '@$handle' : null;
}

/// Single source of truth for "which social accounts are linked".
///
/// Wraps [TikTokService] and re-broadcasts its changes. The profile screen
/// listens to this so the sheet and the icon row repaint when a link is added
/// or removed, instead of showing whatever was true at build time.
class SocialLinksService extends ChangeNotifier {
  SocialLinksService._() {
    TikTokService.instance.addListener(_onTikTokChanged);
  }

  static final SocialLinksService instance = SocialLinksService._();

  /// Platforms offered in the sheet, in display order.
  ///
  /// Deliberately excludes youtube/twitter: [SocialPlatform.iconAsset] points
  /// at youtube.png and twitter.png, but those files are not in assets/icons,
  /// so listing them would throw at image load time.
  static const List<SocialPlatform> _supported = [
    SocialPlatform.tiktok,
    SocialPlatform.instagram,
    SocialPlatform.facebook,
  ];

  void _onTikTokChanged() {
    AppLogger.instance.debug(
      _tag,
      'TikTok connection changed, connected=${TikTokService.instance.isConnected}',
    );
    notifyListeners();
  }

  List<SocialLinkState> get links {
    return _supported.map((platform) {
      if (platform == SocialPlatform.tiktok) {
        final profile = TikTokService.instance.profile;
        return SocialLinkState(
          platform: platform,
          isConnected: TikTokService.instance.isConnected,
          handle: profile?.username,
          hasLinkedPage: true,
        );
      }
      return SocialLinkState(
        platform: platform,
        isConnected: false,
        hasLinkedPage: false,
      );
    }).toList();
  }

  List<SocialLinkState> get connected =>
      links.where((l) => l.isConnected).toList();

  bool get hasAnyConnected => connected.isNotEmpty;

  /// Reload connection state from the backend.
  Future<void> refresh() async {
    await TikTokService.instance.checkConnection();
  }

  @override
  void dispose() {
    TikTokService.instance.removeListener(_onTikTokChanged);
    super.dispose();
  }
}