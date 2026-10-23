import 'package:flutter_test/flutter_test.dart';
import 'package:zumimo_seller/core/tiktok_settings_service.dart';
import 'package:zumimo_seller/models/tiktok_settings.dart';

/// The saved preference must never exceed what the linked account permits —
/// otherwise TikTok rejects the post after the product is already saved.
void main() {
  const publicAccount = TikTokCreator(
    nickname: 'Seller',
    privacyLevelOptions: [
      'PUBLIC_TO_EVERYONE',
      'MUTUAL_FOLLOW_FRIERS',
      'FOLLOWER_OF_CREATOR',
      'SELF_ONLY',
    ],
  );

  const privateAccount = TikTokCreator(
    nickname: 'Sandbox',
    privacyLevelOptions: ['SELF_ONLY'],
  );

  group('TikTokCreator', () {
    test('defaults to SELF_ONLY when the API sends no options', () {
      final creator = TikTokCreator.fromJson({'creator_nickname': 'Test'});
      expect(creator.privacyLevelOptions, ['SELF_ONLY']);
      expect(creator.isPrivateOnly, isTrue);
    });

    test('parses the creator-info payload', () {
      final creator = TikTokCreator.fromJson({
        'creator_nickname': 'Amina',
        'creator_username': 'amina',
        'creator_avatar_url': 'https://cdn.tiktok.com/a.jpg',
        'privacy_level_options': ['MUTUAL_FOLLOW_FRIERS', 'SELF_ONLY'],
        'comment_disabled': true,
        'duet_disabled': true,
        'stitch_disabled': false,
      });

      expect(creator.nickname, 'Amina');
      expect(creator.username, 'amina');
      expect(creator.avatarUrl, 'https://cdn.tiktok.com/a.jpg');
      expect(creator.commentDisabled, isTrue);
      expect(creator.duetDisabled, isTrue);
      expect(creator.stitchDisabled, isFalse);
      expect(creator.isPrivateOnly, isFalse);
    });

    test('picks the most public option the account allows', () {
      expect(publicAccount.defaultPrivacyLevel, 'PUBLIC_TO_EVERYONE');
      expect(privateAccount.defaultPrivacyLevel, 'SELF_ONLY');

      const mid = TikTokCreator(
        privacyLevelOptions: ['MUTUAL_FOLLOW_FRIERS', 'SELF_ONLY'],
      );
      expect(mid.defaultPrivacyLevel, 'MUTUAL_FOLLOW_FRIERS');
    });
  });

  group('TikTokPostSettings JSON', () {
    test('round-trips through toJson/fromJson', () {
      const settings = TikTokPostSettings(
        mode: TikTokPostMode.direct,
        privacyLevel: 'MUTUAL_FOLLOW_FRIERS',
        allowComments: false,
        allowDuet: false,
        allowStitch: true,
        isAigc: true,
      );

      final restored = TikTokPostSettings.fromJson(settings.toJson());
      expect(restored.mode, TikTokPostMode.direct);
      expect(restored.privacyLevel, 'MUTUAL_FOLLOW_FRIERS');
      expect(restored.allowComments, isFalse);
      expect(restored.allowDuet, isFalse);
      expect(restored.allowStitch, isTrue);
      expect(restored.isAigc, isTrue);
    });

    test('falls back to draft and SELF_ONLY on unknown mode', () {
      final settings = TikTokPostSettings.fromJson({'mode': 'nonsense'});
      expect(settings.mode, TikTokPostMode.draft);
      expect(settings.privacyLevel, 'SELF_ONLY');
    });
  });

  group('reconcile', () {
    test('forces SELF_ONLY when creator info is unavailable', () {
      const saved = TikTokPostSettings(privacyLevel: 'PUBLIC_TO_EVERYONE');
      final result = TikTokSettingsService.reconcile(saved, null);
      expect(result.privacyLevel, 'SELF_ONLY');
    });

    test('keeps a still-permitted choice', () {
      const saved = TikTokPostSettings(privacyLevel: 'MUTUAL_FOLLOW_FRIERS');
      final result = TikTokSettingsService.reconcile(saved, publicAccount);
      expect(result.privacyLevel, 'MUTUAL_FOLLOW_FRIERS');
    });

    test('clamps a choice the account no longer permits', () {
      const saved = TikTokPostSettings(privacyLevel: 'PUBLIC_TO_EVERYONE');
      final result =
          TikTokSettingsService.reconcile(saved, privateAccount);
      expect(result.privacyLevel, 'SELF_ONLY');
    });

    test('cannot re-enable interactions the creator disabled', () {
      const saved = TikTokPostSettings(
        allowComments: true,
        allowDuet: true,
        allowStitch: true,
      );
      const creator = TikTokCreator(
        privacyLevelOptions: ['PUBLIC_TO_EVERYONE', 'SELF_ONLY'],
        commentDisabled: true,
        duetDisabled: true,
        stitchDisabled: true,
      );

      final result = TikTokSettingsService.reconcile(saved, creator);
      expect(result.allowComments, isFalse);
      expect(result.allowDuet, isFalse);
      expect(result.allowStitch, isFalse);
    });

    test('still allows switching off what the account permits', () {
      const saved = TikTokPostSettings(allowComments: false);
      final result = TikTokSettingsService.reconcile(saved, publicAccount);
      expect(result.allowComments, isFalse);
      expect(result.allowDuet, isTrue);
    });

    test('never downgrades the chosen mode', () {
      const saved = TikTokPostSettings(mode: TikTokPostMode.direct);
      final result = TikTokSettingsService.reconcile(saved, privateAccount);
      expect(result.mode, TikTokPostMode.direct);
    });
  });

  group('summary', () {
    test('describes mode, privacy and disabled comments', () {
      const settings = TikTokPostSettings(
        mode: TikTokPostMode.direct,
        privacyLevel: 'SELF_ONLY',
        allowComments: false,
      );
      expect(settings.summary, 'Moja kwa moja · Mimi pekee · Hakuna maoni');
    });

    test('uses Swahili labels for privacy levels', () {
      expect(tiktokPrivacyLabel('PUBLIC_TO_EVERYONE'), 'Kila mtu');
      expect(tiktokPrivacyLabel('MUTUAL_FOLLOW_FRIERS'), 'Marafiki tu');
      expect(tiktokPrivacyLabel('FOLLOWER_OF_CREATOR'), 'Wafuasi wangu');
      expect(tiktokPrivacyLabel('SELF_ONLY'), 'Mimi pekee');
      // Unknown values pass through rather than showing a blank row.
      expect(tiktokPrivacyLabel('FUTURE_LEVEL'), 'FUTURE_LEVEL');
    });
  });
}