/// Models for the seller's TikTok posting configuration.
///
/// Two distinct things live here and the distinction matters:
///
///  * [TikTokCreator] is what the **account** allows. It comes from
///    `GET /tiktok/publish/creator-info` and is not editable — TikTok rejects
///    a privacy level the account never declared, and greys out interactions
///    the creator switched off in their own TikTok app.
///  * [TikTokPostSettings] is what the **seller chooses** within those limits.
///    It is persisted and used as the default when a product is posted.
library;

/// How a post should reach TikTok.
enum TikTokPostMode {
  /// Into the seller's TikTok inbox; they finish it in the app. Needs only
  /// `video.upload`, so it works for every seller today.
  draft,

  /// Straight onto the profile. Needs `video.publish`, and is capped at
  /// `SELF_ONLY` until the API client passes TikTok's audit.
  direct,
}

/// Swahili label for a `privacy_level` value.
String tiktokPrivacyLabel(String code) {
  switch (code) {
    case 'PUBLIC_TO_EVERYONE':
      return 'Kila mtu';
    case 'MUTUAL_FOLLOW_FRIERS':
      return 'Marafiki tu';
    case 'FOLLOWER_OF_CREATOR':
      return 'Wafuasi wangu';
    case 'SELF_ONLY':
      return 'Mimi pekee';
    default:
      return code;
  }
}

/// What the linked TikTok account permits.
class TikTokCreator {
  final String? avatarUrl;
  final String? username;
  final String nickname;

  /// Exactly what the API returned. Never widened — TikTok rejects a privacy
  /// level the account did not declare.
  final List<String> privacyLevelOptions;

  /// True when the creator switched this interaction off in their TikTok
  /// settings. The UI must grey it out rather than sending it anyway.
  final bool commentDisabled;
  final bool duetDisabled;
  final bool stitchDisabled;

  const TikTokCreator({
    this.avatarUrl,
    this.username,
    this.nickname = 'TikTok User',
    this.privacyLevelOptions = const ['SELF_ONLY'],
    this.commentDisabled = false,
    this.duetDisabled = false,
    this.stitchDisabled = false,
  });

  factory TikTokCreator.fromJson(Map<String, dynamic> json) {
    final options = json['privacy_level_options'];
    return TikTokCreator(
      avatarUrl: json['creator_avatar_url'] as String?,
      username: json['creator_username'] as String?,
      nickname: json['creator_nickname'] as String? ?? 'TikTok User',
      privacyLevelOptions: options is List && options.isNotEmpty
          ? options.map((e) => e.toString()).toList()
          : const ['SELF_ONLY'],
      commentDisabled: json['comment_disabled'] == true,
      duetDisabled: json['duet_disabled'] == true,
      stitchDisabled: json['stitch_disabled'] == true,
    );
  }

  bool get isPrivateOnly => privacyLevelOptions.every((o) => o == 'SELF_ONLY');

  /// The most public option the account allows, or `SELF_ONLY` as a floor.
  /// Used when the seller has never chosen, and when their saved choice is no
  /// longer permitted.
  String get defaultPrivacyLevel {
    for (final preferred in const [
      'PUBLIC_TO_EVERYONE',
      'MUTUAL_FOLLOW_FRIERS',
      'FOLLOWER_OF_CREATOR',
      'SELF_ONLY',
    ]) {
      if (privacyLevelOptions.contains(preferred)) return preferred;
    }
    return privacyLevelOptions.isNotEmpty
        ? privacyLevelOptions.first
        : 'SELF_ONLY';
  }
}

/// The seller's saved posting preferences.
class TikTokPostSettings {
  final TikTokPostMode mode;
  final String privacyLevel;
  final bool allowComments;
  final bool allowDuet;
  final bool allowStitch;

  /// TikTok's AI-generated-content declaration. Off unless the seller says the
  /// video was AI-generated — it adds an AIGC label to the post.
  final bool isAigc;

  const TikTokPostSettings({
    this.mode = TikTokPostMode.draft,
    this.privacyLevel = 'SELF_ONLY',
    this.allowComments = true,
    this.allowDuet = true,
    this.allowStitch = true,
    this.isAigc = false,
  });

  factory TikTokPostSettings.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'];
    return TikTokPostSettings(
      mode: mode == 'direct' ? TikTokPostMode.direct : TikTokPostMode.draft,
      privacyLevel: json['privacy_level'] as String? ?? 'SELF_ONLY',
      allowComments: json['allow_comments'] as bool? ?? true,
      allowDuet: json['allow_duet'] as bool? ?? true,
      allowStitch: json['allow_stitch'] as bool? ?? true,
      isAigc: json['is_aigc'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'privacy_level': privacyLevel,
        'allow_comments': allowComments,
        'allow_duet': allowDuet,
        'allow_stitch': allowStitch,
        'is_aigc': isAigc,
      };

  TikTokPostSettings copyWith({
    TikTokPostMode? mode,
    String? privacyLevel,
    bool? allowComments,
    bool? allowDuet,
    bool? allowStitch,
    bool? isAigc,
  }) {
    return TikTokPostSettings(
      mode: mode ?? this.mode,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      allowComments: allowComments ?? this.allowComments,
      allowDuet: allowDuet ?? this.allowDuet,
      allowStitch: allowStitch ?? this.allowStitch,
      isAigc: isAigc ?? this.isAigc,
    );
  }

  /// One-line summary shown next to the product form's TikTok switch, so the
  /// seller can see what will be used without opening settings.
  String get summary {
    final parts = <String>[
      mode == TikTokPostMode.draft ? 'Draft' : 'Moja kwa moja',
      tiktokPrivacyLabel(privacyLevel),
    ];
    if (!allowComments) parts.add('Hakuna maoni');
    return parts.join(' · ');
  }
}