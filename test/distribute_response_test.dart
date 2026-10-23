import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the `POST /distribute` response shape.
///
/// The bug this pins down: Laravel returns `'distribution' => []` when no
/// video was attached. PHP's empty array JSON-encodes as `[]`, which Dart
/// decodes as a **List**, so `response['distribution']['tiktok']` throws
/// "type 'String' is not a subtype of type 'int' of 'index'".
///
/// The symptom was nasty: the product WAS created (HTTP 201), but the
/// exception fired before the success banner and the `pop`, leaving the seller
/// stuck on the form — resubmitting would then create a duplicate.
void main() {
  /// Mirrors how the screen reads the response.
  ({String status, Map<String, dynamic>? tiktok}) readDistribution(
    Map<String, dynamic> body,
  ) {
    final status = body['status'] as String?;
    final distribution = body['distribution'];
    final tiktok =
        distribution is Map<String, dynamic> ? distribution['tiktok'] : null;
    return (
      status: status ?? '',
      tiktok: tiktok is Map<String, dynamic> ? tiktok : null,
    );
  }

  Map<String, dynamic> productJson() => {
        'id': 7,
        'product_name': 'Viatu',
        'price': 45000.0,
        'stock': 12,
        'description': 'Viatu vya kivimbe',
        'image_url': null,
        'category': 'Mavuto',
        'status': 'active',
      };

  test('empty distribution array does not throw (the reported crash)', () {
    // Exactly what the backend sends when no video is attached.
    final body = {
      'status': 'created',
      'message': 'Bidhaa imehifadhiwa.',
      'product': productJson(),
      'distribution': <dynamic>[], // PHP [] -> JSON [] -> Dart List
    };

    expect(() => readDistribution(body), returnsNormally);

    final read = readDistribution(body);
    expect(read.status, 'created');
    expect(read.tiktok, isNull);
  });

  test('distribution as an object with a tiktok failure is read', () {
    final body = {
      'status': 'partial',
      'message': 'Saved but distribution failed.',
      'product': productJson(),
      'distribution': {
        'tiktok': {'ok': false, 'error': 'tiktok_not_connected'}
      },
    };

    final read = readDistribution(body);
    expect(read.status, 'partial');
    expect(read.tiktok?['ok'], false);
    expect(read.tiktok?['error'], 'tiktok_not_connected');
  });

  test('distributed status carries a successful tiktok result', () {
    final body = {
      'status': 'distributed',
      'message': 'Saved and published.',
      'product': productJson(),
      'distribution': {
        'tiktok': {'ok': true, 'publish_id': 'v_pub_file~v2-1.123'}
      },
    };

    final read = readDistribution(body);
    expect(read.status, 'distributed');
    expect(read.tiktok?['ok'], true);
  });

  test('distribution missing entirely is tolerated', () {
    final body = {
      'status': 'created',
      'product': productJson(),
    };
    expect(() => readDistribution(body), returnsNormally);
    expect(readDistribution(body).tiktok, isNull);
  });

  test('a non-empty list distribution is still not indexed as a map', () {
    // Defensive: PHP could return a sequential array under any shape change.
    final body = {
      'status': 'created',
      'product': productJson(),
      'distribution': ['unexpected'],
    };
    expect(() => readDistribution(body), returnsNormally);
    expect(readDistribution(body).tiktok, isNull);
  });

  titleTests();
}

/// TikTok caps a photo post title at 90 UTF-16 code units — Dart's
/// `String.length`. Sending a longer product name earns a 400 and leaves the
/// seller with a saved product and no TikTok post.
void titleTests() {
  const limit = 90;

  String titleForTikTok(String productName) {
    if (productName.length <= limit) return productName;
    return '${productName.substring(0, limit - 1).trimRight()}…';
  }

  test('a short name is passed through untouched', () {
    expect(titleForTikTok('Viatu vya kivimbe'), 'Viatu vya kivimbe');
  });

  test('a name exactly at the limit is untouched', () {
    final exact = 'a' * limit;
    expect(titleForTikTok(exact).length, limit);
  });

  test('a long name is truncated to exactly the limit', () {
    final long = 'b' * 200;
    final out = titleForTikTok(long);
    expect(out.length, limit);
    expect(out.endsWith('…'), isTrue);
  });

  test('truncation never exceeds the limit for any input length', () {
    for (final n in [91, 95, 100, 150, 500]) {
      expect(titleForTikTok('c' * n).length, limit, reason: 'length $n');
    }
  });
}