import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zumimo_seller/core/tiktok_service.dart';

/// Regression tests for the crash reported on device:
///
///   setState() or markNeedsBuild() called during build.
///     ListenableBuilder
///     <- SocialLinksService._onTikTokChanged
///     <- TikTokService.checkConnection          (tiktok_service.dart:27)
///     <- TikTokScreen._loadData
///     <- TikTokScreen.initState
///
/// An `async` method body runs synchronously up to its first `await`. The
/// `notifyListeners()` at the top of `checkConnection()` therefore fired while
/// `initState` — and so the build phase — was still on the stack. Once
/// something actually listened (the profile screen's ListenableBuilder), that
/// made the listener mark itself dirty mid-build, which Flutter rejects.
///
/// The invariant under test: checkConnection must never notify synchronously.
///
/// Note these tests deliberately do NOT await the returned future. It performs
/// a real HTTP call, and these tests run with no network; awaiting it makes the
/// suite hang rather than fail.
void main() {
  test('checkConnection does not notify listeners synchronously', () {
    final service = TikTokService.instance;

    var notified = false;
    void listener() => notified = true;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    // Fire and forget. The assertion below runs while we are still on this
    // stack — i.e. before any microtask, and therefore before any point where
    // a notify would be legitimate.
    unawaited(service.checkConnection());

    expect(
      notified,
      isFalse,
      reason: 'A synchronous notify during a call from initState breaks any '
          'mounted ListenableBuilder. It must be deferred to a microtask.',
    );
  });

  test('the deferred notification does arrive', () async {
    final service = TikTokService.instance;

    var count = 0;
    void listener() => count++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    count = 0;
    unawaited(service.checkConnection());

    // Let the scheduled microtask run.
    await Future<void>.delayed(Duration.zero);

    expect(count, greaterThan(0),
        reason: 'deferring must delay the notification, not swallow it');
  });

  test('every entry point defers its first notification', () async {
    final service = TikTokService.instance;

    // Each of these sets isLoading and notifies before awaiting anything.
    // They must all defer, because each can be reached from a build-phase
    // call site in future.
    for (final invoke in <Future<Object?> Function()>[
      () => service.checkConnection(),
      () => service.disconnect(),
      () => service.syncProfile(),
      () => service.handleCallback('code', 'state'),
    ]) {
      var notified = false;
      void listener() => notified = true;
      service.addListener(listener);

      unawaited(invoke());

      expect(notified, isFalse,
          reason: '${invoke.runtimeType} notified synchronously');

      service.removeListener(listener);
      await Future<void>.delayed(Duration.zero);
    }
  });

  testWidgets('a listener notified outside build rebuilds cleanly',
      (tester) async {
    // The flip side of the fix: deferring must not break normal repaints.
    final service = TikTokService.instance;
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            builds++;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final initial = builds;

    // Safe: triggered from a post-frame callback, i.e. outside build.
    tester.binding.addPostFrameCallback((_) {
      unawaited(service.checkConnection());
    });
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(builds, greaterThan(initial),
        reason: 'the listener should still cause a rebuild');
  });
}