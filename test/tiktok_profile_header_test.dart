import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zumimo_seller/models/tiktok_model.dart';
import 'package:zumimo_seller/widgets/tiktok_profile_header.dart';

/// Layout tests for the real [TikTokProfileHeader] widget.
///
/// These assert the requested structure directly: a large avatar on the left,
/// the name and username to its right, and the unlink control on that same
/// horizontal line.
void main() {
  TikTokProfile profile({
    String? displayName = 'Duka Langu',
    String? username = 'dukalingu',
    String? bio = 'Bidhaa za asili kutoka Tanzania',
    bool isVerified = false,
  }) {
    return TikTokProfile(
      displayName: displayName,
      username: username,
      // No avatarUrl: keeps the test offline (no Image.network).
      avatarUrl: null,
      bioDescription: bio,
      isVerified: isVerified,
      followerCount: 1250,
      followingCount: 340,
      likesCount: 8900,
      videoCount: 45,
    );
  }

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('avatar is on the left at 96px, larger than the old 72px',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(profile: profile(), onUnlink: () {}),
    ));

    final avatar = tester.getRect(
      find.byKey(const Key('tiktok_header_avatar')),
    );
    expect(avatar.width, 96);
    expect(avatar.height, 96);
  });

  testWidgets('avatar, name, username and unlink share one horizontal line',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(profile: profile(), onUnlink: () {}),
    ));

    final avatar = tester.getRect(
      find.byKey(const Key('tiktok_header_avatar')),
    );
    final name = tester.getRect(find.text('Duka Langu'));
    final username = tester.getRect(find.text('@dukalingu'));
    final unlink = tester.getRect(
      find.byKey(const Key('tiktok_header_unlink')),
    );

    // Same vertical band as the avatar.
    expect(name.center.dy, moreOrLessEquals(avatar.center.dy, epsilon: 26));
    expect(unlink.center.dy, moreOrLessEquals(avatar.center.dy, epsilon: 26));
    // Username sits below the name, inside the same block.
    expect(username.center.dy, greaterThan(name.center.dy));

    // Horizontal order: avatar, then the text block, then unlink.
    expect(avatar.left, lessThan(name.left));
    expect(name.left, lessThan(unlink.left));
  });

  testWidgets('tapping the unlink control fires the callback', (tester) async {
    var unlinked = 0;
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(
        profile: profile(),
        onUnlink: () => unlinked++,
      ),
    ));

    await tester.tap(find.byKey(const Key('tiktok_header_unlink')));
    expect(unlinked, 1);
  });

  testWidgets('a long name ellipsises instead of overflowing', (tester) async {
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(
        profile: profile(
          displayName: 'Duka Langu la Mzee Yusuf bin Mohammed al-Hassan',
        ),
        onUnlink: () {},
      ),
    ));

    expect(tester.takeException(), isNull);
    final name = tester.getRect(find.textContaining('Duka Langu la Mzee'));
    final unlink = tester.getRect(
      find.byKey(const Key('tiktok_header_unlink')),
    );
    expect(name.right, lessThanOrEqualTo(unlink.left));
  });

  testWidgets('stats and bio are shown below the identity row',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(profile: profile(), onUnlink: () {}),
    ));

    // 1250 followers renders as 1.3K via formattedFollowers.
    expect(find.text('1.3K'), findsOneWidget);
    expect(find.text('Wafuasi'), findsOneWidget);
    expect(find.textContaining('Bidhaa za asili'), findsOneWidget);

    final avatar = tester.getRect(
      find.byKey(const Key('tiktok_header_avatar')),
    );
    final followers = tester.getRect(find.text('Wafuasi'));
    expect(followers.top, greaterThan(avatar.bottom));
  });

  testWidgets('omits the username row when there is no username', (tester) async {
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(
        profile: profile(username: null),
        onUnlink: () {},
      ),
    ));

    expect(find.text('@dukalingu'), findsNothing);
    // Display name is unaffected by the missing username.
    expect(find.text('Duka Langu'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder when there is no display name',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokProfileHeader(
        profile: profile(displayName: null),
        onUnlink: () {},
      ),
    ));

    expect(find.text('TikTok User'), findsOneWidget);
  });
}