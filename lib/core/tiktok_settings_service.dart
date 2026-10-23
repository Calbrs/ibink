import 'package:flutter/foundation.dart';

import '../models/tiktok_settings.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'app_logger.dart';
import 'local_storage.dart';

const String _tag = 'TikTokSettings';

/// Owns the seller's TikTok posting preferences.
///
/// The important rule here: **the saved choice is never allowed to exceed what
/// the account permits.** TikTok rejects a `privacy_level` the account did not
/// declare, and greys out interactions the creator disabled in their own TikTok
/// app. So on every load the saved settings are reconciled against the live
/// creator info rather than trusted as-is — otherwise a seller who picked
/// "Kila mtu" months ago, before their app was approved, would silently start
/// getting 400s.
class TikTokSettingsService extends ChangeNotifier {
  TikTokSettingsService._() {
    _settings = _readStored();
    _creator = _storedCreator();
  }

  static final TikTokSettingsService instance = TikTokSettingsService._();

  late TikTokPostSettings _settings;
  TikTokCreator? _creator;
  bool _isLoading = false;

  TikTokPostSettings get settings => _settings;
  TikTokCreator? get creator => _creator;
  bool get isLoading => _isLoading;

  bool get hasCreatorInfo => _creator != null;

  // --------------------------------------------------------------------
  // LOADING
  // --------------------------------------------------------------------

  /// Fetches live capabilities and reconciles the saved settings against them.
  Future<TikTokCreator?> refreshCreatorInfo() async {
    _isLoading = true;
    notifyListeners();

    final res =
        await ApiClient.instance.get(ApiConfig.tiktokCreatorInfoEndpoint);
    _isLoading = false;

    if (!res.success || res.data == null) {
      AppLogger.instance.warn(
        _tag,
        'creator-info failed (${res.statusCode}): ${res.error}',
      );
      notifyListeners();
      return null;
    }

    final raw = res.data!['creator'];
    if (raw is! Map<String, dynamic>) {
      AppLogger.instance.error(_tag, 'creator-info had no `creator` object.');
      notifyListeners();
      return null;
    }

    final creator = TikTokCreator.fromJson(raw);
    _creator = creator;
    _settings = reconcile(_settings, creator);

    AppLogger.instance.info(
      _tag,
      'creator @${creator.username} '
      'privacy=${creator.privacyLevelOptions.join(",")} '
      'disabled=[${[
        if (creator.commentDisabled) 'comment',
        if (creator.duetDisabled) 'duet',
        if (creator.stitchDisabled) 'stitch',
      ].join(",")}] '
      '→ settings ${_settings.summary}',
    );

    await _persistCreator();
    notifyListeners();
    return creator;
  }

  /// Clamps [current] to what [creator] allows.
  ///
  /// Exposed for tests: the clamping rules are the part worth pinning down.
  @visibleForTesting
  static TikTokPostSettings reconcile(
    TikTokPostSettings current,
    TikTokCreator? creator,
  ) {
    // No live info: fall back to the safest thing that always works.
    if (creator == null) {
      return current.copyWith(privacyLevel: 'SELF_ONLY');
    }

    // TikTok only accepts a declared privacy level. A private account gets
    // SELF_ONLY because that is the only option it declared — that is exactly
    // the "account is private" case the seller needs explained.
    final privacy = creator.privacyLevelOptions.contains(current.privacyLevel)
        ? current.privacyLevel
        : creator.defaultPrivacyLevel;

    // Interactions the creator disabled cannot be re-enabled from here, but an
    // interaction they *allow* can still be chosen off.
    final comments =
        creator.commentDisabled ? false : current.allowComments;
    final duet = creator.duetDisabled ? false : current.allowDuet;
    final stitch = creator.stitchDisabled ? false : current.allowStitch;

    return current.copyWith(
      privacyLevel: privacy,
      allowComments: comments,
      allowDuet: duet,
      allowStitch: stitch,
    );
  }

  // --------------------------------------------------------------------
  // MUTATION
  // --------------------------------------------------------------------

  Future<void> update(TikTokPostSettings next) async {
    // Never persist something the account would reject.
    _settings = reconcile(next, _creator);
    await _save();
    AppLogger.instance.info(_tag, 'settings updated → ${_settings.summary}');
    notifyListeners();
  }

  Future<void> setMode(TikTokPostMode mode) =>
      update(_settings.copyWith(mode: mode));

  Future<void> setPrivacy(String level) =>
      update(_settings.copyWith(privacyLevel: level));

  Future<void> setComments(bool value) =>
      update(_settings.copyWith(allowComments: value));

  Future<void> setDuet(bool value) => update(_settings.copyWith(allowDuet: value));

  Future<void> setStitch(bool value) =>
      update(_settings.copyWith(allowStitch: value));

  Future<void> setAigc(bool value) => update(_settings.copyWith(isAigc: value));

  /// Back to the account's own defaults: the most public option it permits,
  /// with all interactions allowed.
  Future<void> resetToAccountDefaults() async {
    _settings = reconcile(
      const TikTokPostSettings(),
      _creator,
    );
    await _save();
    AppLogger.instance.info(
      _tag,
      'settings reset to account defaults → ${_settings.summary}',
    );
    notifyListeners();
  }

  /// Persist anything still queued before the process goes away.
  Future<void> flush() async {
    await _save();
    await AppLogger.instance.guard(
      'TikTokSettings',
      'refresh creator info on save',
      () => refreshCreatorInfo(),
    );
  }

  // --------------------------------------------------------------------
  // STORAGE
  // --------------------------------------------------------------------

  TikTokPostSettings _readStored() {
    final raw = LocalStorage.instance.getTikTokSettings();
    if (raw == null) return const TikTokPostSettings();
    return TikTokPostSettings.fromJson(raw);
  }

  TikTokCreator? _storedCreator() {
    final raw = LocalStorage.instance.getTikTokSettings();
    final creator = raw?['creator'];
    return creator is Map<String, dynamic> ? TikTokCreator.fromJson(creator) : null;
  }

  Future<void> _save() async {
    await LocalStorage.instance.saveTikTokSettings(_settings.toJson());
  }

  Future<void> _persistCreator() async {
    final creator = _creator;
    if (creator == null) return;
    await LocalStorage.instance.saveTikTokSettings({
      ..._settings.toJson(),
      'creator': {
        'creator_avatar_url': creator.avatarUrl,
        'creator_username': creator.username,
        'creator_nickname': creator.nickname,
        'privacy_level_options': creator.privacyLevelOptions,
        'comment_disabled': creator.commentDisabled,
        'duet_disabled': creator.duetDisabled,
        'stitch_disabled': creator.stitchDisabled,
      },
    });
  }
}