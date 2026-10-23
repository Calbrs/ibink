import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zumimo_seller/models/tiktok_model.dart';
import 'package:zumimo_seller/screens/tiktok/tiktok_videos_screen.dart';

/// Tests for [TikTokVideoTile] — the clickable/playable cell in the video grid.
void main() {
  TikTokVideo video({
    String id = '7077642457847994444',
    String? title = 'Product showcase #tanzania',
    String? description = 'Check out our new products',
    String? coverImageUrl,
    int? duration = 30,
  }) {
    return TikTokVideo(
      id: id,
      title: title,
      description: description,
      // Left null so the test stays offline (no Image.network).
      coverImageUrl: coverImageUrl,
      embedLink: 'https://www.tiktok.com/embed/v2/$id',
      duration: duration,
    );
  }

  /// The tile uses StackFit.expand, so it must be given bounded constraints —
  /// in the app it lives inside a GridView cell.
  Widget wrap(Widget child, {double side = 180}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: side,
            height: side * 1.2,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title and a formatted duration', (tester) async {
    await tester.pumpWidget(wrap(
      TikTokVideoTile(video: video(), onTap: () {}),
    ));

    expect(find.text('Product showcase #tanzania'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
  });

  testWidgets('is clickable and reports which video was tapped', (tester) async {
    String? tappedId;
    await tester.pumpWidget(wrap(
      TikTokVideoTile(
        video: video(id: '12345'),
        onTap: () => tappedId = '12345',
      ),
    ));

    await tester.tap(find.byKey(const Key('video_tile_12345')));
    expect(tappedId, '12345');
  });

  testWidgets('shows a play affordance so it reads as playable',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokVideoTile(video: video(), onTap: () {}),
    ));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('falls back to the description when there is no title',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokVideoTile(video: video(title: null), onTap: () {}),
    ));

    expect(find.text('Check out our new products'), findsOneWidget);
  });

  testWidgets('renders no title when there is neither title nor description',
      (tester) async {
    await tester.pumpWidget(wrap(
      TikTokVideoTile(
        video: video(title: null, description: null),
        onTap: () {},
      ),
    ));

    // Nothing to label it with, but the tile must still build.
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('video_tile_7077642457847994444')),
        findsOneWidget);
  });

  testWidgets('handles a missing duration without crashing', (tester) async {
    await tester.pumpWidget(wrap(
      TikTokVideoTile(video: video(duration: null), onTap: () {}),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('a very long title is ellipsised, not overflowed', (tester) async {
    await tester.pumpWidget(wrap(
      TikTokVideoTile(
        video: video(
          title: 'Bidhaa za asili kutoka mji wa Tanga zilizopelekwa kwa '
              'maghribi na wateja wote wa duka hili',
        ),
        onTap: () {},
      ),
    ));

    expect(tester.takeException(), isNull);

    final text = tester.widget<Text>(find.textContaining('Bidhaa za asili'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}