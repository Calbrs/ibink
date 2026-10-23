import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'api_client.dart';
import 'api_config.dart';
import '../models/tiktok_model.dart';

const String _tag = 'TikTok';

class TikTokService extends ChangeNotifier {
  TikTokService._();
  static final TikTokService instance = TikTokService._();

  TikTokProfile? _profile;
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;

  TikTokProfile? get profile => _profile;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Notifies on the next microtask instead of immediately.
  ///
  /// An `async` method body runs synchronously up to its first `await`, so a
  /// plain `notifyListeners()` at the top of `checkConnection()` fires while
  /// the caller is still on the caller's stack. When that caller is
  /// `initState` — as it is in TikTokScreen and ProfileScreen — we are inside
  /// the build phase, and notifying synchronously makes any listening widget
  /// (e.g. a ListenableBuilder) mark itself dirty mid-build, which Flutter
  /// rejects with "setState() or markNeedsBuild() called during build".
  ///
  /// Deferring by one microtask keeps the same ordering guarantee for callers
  /// while guaranteeing we are out of the build phase.
  void _notifyDeferred() {
    scheduleMicrotask(notifyListeners);
  }

  Future<void> checkConnection() async {
    _isLoading = true;
    _error = null;
    _notifyDeferred();

    try {
      final res = await ApiClient.instance.get(ApiConfig.tiktokProfileEndpoint);

      if (res.success && res.data != null) {
        _isConnected = res.data!['connected'] == true;
        if (_isConnected && res.data!['profile'] != null) {
          _profile = TikTokProfile.fromJson(res.data!['profile']);
          AppLogger.instance.info(
            _tag,
            'Connected: @${_profile?.username ?? '?'} '
            'followers=${_profile?.followerCount} videos=${_profile?.videoCount}',
          );
        } else {
          _profile = null;
          AppLogger.instance.debug(_tag, 'Not connected (backend reports connected=false).');
        }
      } else {
        _isConnected = false;
        _profile = null;
        AppLogger.instance.warn(_tag, 'checkConnection failed: ${res.error}');
      }
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'checkConnection threw', e, st);
      _isConnected = false;
      _profile = null;
      _error = 'Imeshindwa kupakua taarifa za TikTok';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> getAuthUrl() async {
    AppLogger.instance.info(_tag, 'Requesting OAuth authorize URL…');
    try {
      final res = await ApiClient.instance.get(ApiConfig.tiktokAuthUrlEndpoint);
      if (res.success && res.data != null) {
        final url = res.data!['url'] as String?;
        AppLogger.instance.info(_tag, 'Authorize URL received (len=${url?.length ?? 0}).');
        return url;
      }
      AppLogger.instance.warn(_tag, 'getAuthUrl failed: ${res.error}');
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'getAuthUrl threw', e, st);
    }
    return null;
  }

  Future<bool> handleCallback(String code, String state) async {
    _isLoading = true;
    _error = null;
    _notifyDeferred();

    // The values themselves are credentials in flight — log only their length
    // and shape so the log is safe to share.
    AppLogger.instance.info(
      _tag,
      'Callback received: code len=${code.length}, state len=${state.length}',
    );

    try {
      final res = await ApiClient.instance.post(
        ApiConfig.tiktokCallbackEndpoint,
        {'code': code, 'state': state},
      );

      if (res.success) {
        AppLogger.instance.info(_tag, 'Callback accepted by backend.');
        await checkConnection();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        AppLogger.instance.warn(_tag, 'Callback rejected: ${res.error}');
        _error = res.error ?? 'Imeshindwa kuunganisha TikTok';
      }
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'handleCallback threw', e, st);
      _error = 'Hitilafu imetokea';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> disconnect() async {
    _isLoading = true;
    _error = null;
    _notifyDeferred();

    try {
      final res = await ApiClient.instance.post(
        ApiConfig.tiktokDisconnectEndpoint,
        {},
      );

      if (res.success) {
        _profile = null;
        _isConnected = false;
        _isLoading = false;
        notifyListeners();
        AppLogger.instance.info(_tag, 'Disconnected.');
        return true;
      } else {
        AppLogger.instance.warn(_tag, 'disconnect failed: ${res.error}');
        _error = res.error ?? 'Imeshindwa kutoa muunganisho';
      }
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'disconnect threw', e, st);
      _error = 'Hitilafu imetokea';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> syncProfile() async {
    _isLoading = true;
    _error = null;
    _notifyDeferred();

    try {
      final res = await ApiClient.instance.post(
        ApiConfig.tiktokSyncEndpoint,
        {},
      );

      if (res.success) {
        AppLogger.instance.info(_tag, 'Profile sync completed.');
        await checkConnection();
        return true;
      } else {
        AppLogger.instance.warn(_tag, 'syncProfile failed: ${res.error}');
        _error = res.error ?? 'Imeshindwa Sasisha';
      }
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'syncProfile threw', e, st);
      _error = 'Hitilafu imetokea';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<List<TikTokVideo>> getVideos() async {
    try {
      final res = await ApiClient.instance.get(ApiConfig.tiktokVideosEndpoint);

      if (res.success && res.data != null) {
        final data = res.data!['data'];
        if (data != null && data['videos'] != null) {
          final videos = data['videos'] as List;
          final parsed = videos.map((v) => TikTokVideo.fromJson(v)).toList();
          AppLogger.instance.info(_tag, 'Fetched ${parsed.length} video(s).');
          return parsed;
        }
        AppLogger.instance.warn(_tag, 'getVideos: response had no videos list.');
      } else {
        AppLogger.instance.warn(_tag, 'getVideos failed: ${res.error}');
      }
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'getVideos threw', e, st);
    }
    return [];
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
