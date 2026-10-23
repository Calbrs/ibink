import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'app_logger.dart';
import 'api_config.dart';
import 'session.dart';

const String _tag = 'ApiClient';

/// How much of a failing response body to keep in the log. Enough to see a
/// Laravel validation message, not enough to bloat the file.
const int _bodyExcerptLimit = 600;

MediaType _resolveImageContentType(String filePath) {
  final guessed = lookupMimeType(filePath);
  if (guessed != null) {
    final parts = guessed.split('/');
    return MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
  }

  try {
    final bytes = File(filePath).readAsBytesSync();
    final header = bytes.length > 12 ? bytes.sublist(0, 12) : bytes;
    final byMagic = lookupMimeType(filePath, headerBytes: header);
    if (byMagic != null) {
      final parts = byMagic.split('/');
      return MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
    }
  } catch (_) {
    // Ignore
  }

  return MediaType('image', 'jpeg');
}

class ApiResponse<T> {
  final T? data;
  final String? error;
  final Map<String, List<String>>? fieldErrors;

  /// Extra machine-readable context from a failed request, e.g. Laravel's
  /// `details`. The TikTok backend forwards TikTok's own `error.code` here
  /// (`scope_not_authorized`, `rate_limit_exceeded`, …) and the app has to be
  /// able to tell "reconnect TikTok" apart from "try again" — a human-readable
  /// message alone cannot express that.
  final Map<String, dynamic>? details;

  final int statusCode;
  final bool success;

  const ApiResponse({
    this.data,
    this.error,
    this.fieldErrors,
    this.details,
    required this.statusCode,
    required this.success,
  });

  factory ApiResponse.ok(T data, int code) =>
      ApiResponse(data: data, statusCode: code, success: true);

  factory ApiResponse.err(
    String msg,
    int code, {
    Map<String, List<String>>? fieldErrors,
    Map<String, dynamic>? details,
  }) => ApiResponse(
    error: msg,
    fieldErrors: fieldErrors,
    details: details,
    statusCode: code,
    success: false,
  );

  /// TikTok's machine error code, when the backend forwarded one.
  String? get upstreamCode {
    final value = details?['code'];
    return value is String && value.isNotEmpty ? value : null;
  }

  bool fieldErrorContains(String field, String contains) {
    final messages = fieldErrors?[field];
    if (messages == null) return false;
    final needle = contains.toLowerCase();
    return messages.any((m) => m.toLowerCase().contains(needle));
  }
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();
  String? _token;
  String? _phoneToken;

  // Laravel session cookies. The onbaio backend authenticates via
  // `Auth::guard('seller')->login` (session cookie) rather than returning
  // a bearer token everywhere, so responses' Set-Cookie values are kept
  // and replayed on every request.
  final Map<String, String> _cookies = {};

  void setToken(String token) {
    _token = token;
    // Never log the value itself — the log file gets shared for support.
    AppLogger.instance.info(_tag, 'Auth token set (len=${token.length}).');
  }

  void setPhoneToken(String token) {
    _phoneToken = token;
    AppLogger.instance.info(_tag, 'Phone token set (len=${token.length}).');
  }

  void clearPhoneToken() {
    _phoneToken = null;
    AppLogger.instance.debug(_tag, 'Phone token cleared.');
  }

  void clearToken() {
    _token = null;
    _phoneToken = null;
    _cookies.clear();
    AppLogger.instance.info(_tag, 'Tokens cleared.');
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;
  bool get hasPhoneToken => _phoneToken != null && _phoneToken!.isNotEmpty;

  void restoreTokenFromSession() {
    final saved = Session.instance.token;
    if (saved != null && saved.isNotEmpty) {
      _token = saved;
      AppLogger.instance.info(_tag, 'Auth token restored from session.');
    }
    final savedPhoneToken = Session.instance.phoneToken;
    if (savedPhoneToken != null && savedPhoneToken.isNotEmpty) {
      _phoneToken = savedPhoneToken;
      AppLogger.instance.info(_tag, 'Phone token restored from session.');
    }
  }

  void ensureTokenIsSet() {
    final session = Session.instance;

    if (session.token != null && session.token!.isNotEmpty) {
      if (_token == null || _token!.isEmpty) {
        _token = session.token;
        AppLogger.instance.debug(_tag, 'Auth token re-attached from session.');
      }
    }

    if (session.phoneToken != null && session.phoneToken!.isNotEmpty) {
      if (_phoneToken == null || _phoneToken!.isEmpty) {
        _phoneToken = session.phoneToken;
        AppLogger.instance.debug(_tag, 'Phone token re-attached from session.');
      }
    }
  }

  Map<String, String> get _headers {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    if (_phoneToken != null && _phoneToken!.isNotEmpty) {
      headers[ApiConfig.phoneTokenHeader] = _phoneToken!;
    }

    final cookie = _cookieHeader;
    if (cookie != null) headers['Cookie'] = cookie;

    // Laravel's CSRF middleware accepts the (encrypted) XSRF-TOKEN cookie
    // value signed as the X-XSRF-TOKEN header on POST/PUT/PATCH/DELETE.
    final xsrf = _cookies['XSRF-TOKEN'];
    if (xsrf != null && xsrf.isNotEmpty) {
      headers['X-XSRF-TOKEN'] = Uri.decodeComponent(xsrf);
    }

    return headers;
  }

  String? get _cookieHeader {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Sentry + Laravel merge multiple Set-Cookie headers into one
  /// comma-joined `set-cookie` value; a cookie boundary is a comma
  /// followed by a new `name=` pair (dates like `Expires=Tue, 09 ...`
  /// are not followed by `=` so they don't split).
  void _storeCookies(Map<String, String> resHeaders) {
    final raw = resHeaders['set-cookie'];
    if (raw == null || raw.isEmpty) return;

    final parts = raw.split(RegExp(r',+\s*(?=[A-Za-z0-9_.-]+=)'));
    for (final part in parts) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final name = part.substring(0, eq).trim();
      var value = part.substring(eq + 1);
      final semi = value.indexOf(';');
      if (semi >= 0) value = value.substring(0, semi);
      if (name.isEmpty || value.isEmpty) continue;
      _cookies[name] = value;
      AppLogger.instance.debug(_tag, '← set-cookie: $name');
    }
  }

  // --------------------------------------------------------------------
  // VERBS
  // --------------------------------------------------------------------

  Future<ApiResponse<Map<String, dynamic>>> get(String endpoint) async {
    final label = 'GET $endpoint';
    final sw = Stopwatch()..start();
    AppLogger.instance.debug(_tag, '→ $label');

    _warnIfTokenExpected(endpoint);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final res = await _client
          .get(url, headers: _headers)
          .timeout(ApiConfig.receiveTimeout);
      sw.stop();
      AppLogger.instance.info(
        _tag,
        '← $label ${res.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return _handle(res, label);
    } on SocketException catch (e) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label no internet (${sw.elapsedMilliseconds}ms)',
        e,
      );
      return ApiResponse.err('No internet connection.', 0);
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label threw (${sw.elapsedMilliseconds}ms)',
        e,
        st,
      );
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
    String? phoneToken,
  }) async {
    final label = 'POST $endpoint';
    final sw = Stopwatch()..start();
    AppLogger.instance.debug(_tag, '→ $label body=${_summarizeBody(body)}');

    try {
      _warnIfTokenExpected(endpoint);
      final headers = _headersWithOverrides(token, phoneToken);

      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final jsonBody = jsonEncode(body);

      final res = await _client
          .post(url, headers: headers, body: jsonBody)
          .timeout(ApiConfig.receiveTimeout);
      sw.stop();
      AppLogger.instance.info(
        _tag,
        '← $label ${res.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return _handle(res, label);
    } on SocketException catch (e) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label no internet (${sw.elapsedMilliseconds}ms)',
        e,
      );
      return ApiResponse.err('No internet connection.', 0);
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label threw (${sw.elapsedMilliseconds}ms)',
        e,
        st,
      );
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final label = 'PUT $endpoint';
    final sw = Stopwatch()..start();
    AppLogger.instance.debug(_tag, '→ $label body=${_summarizeBody(body)}');

    _warnIfTokenExpected(endpoint);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final res = await _client
          .put(url, headers: _headers, body: jsonEncode(body))
          .timeout(ApiConfig.receiveTimeout);
      sw.stop();
      AppLogger.instance.info(
        _tag,
        '← $label ${res.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return _handle(res, label);
    } on SocketException catch (e) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label no internet (${sw.elapsedMilliseconds}ms)',
        e,
      );
      return ApiResponse.err('No internet connection.', 0);
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label threw (${sw.elapsedMilliseconds}ms)',
        e,
        st,
      );
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final label = 'PATCH $endpoint';
    final sw = Stopwatch()..start();
    AppLogger.instance.debug(_tag, '→ $label body=${_summarizeBody(body)}');

    _warnIfTokenExpected(endpoint);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final res = await _client
          .patch(url, headers: _headers, body: jsonEncode(body))
          .timeout(ApiConfig.receiveTimeout);
      sw.stop();
      AppLogger.instance.info(
        _tag,
        '← $label ${res.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return _handle(res, label);
    } on SocketException catch (e) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label no internet (${sw.elapsedMilliseconds}ms)',
        e,
      );
      return ApiResponse.err('No internet connection.', 0);
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label threw (${sw.elapsedMilliseconds}ms)',
        e,
        st,
      );
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(String endpoint) async {
    final label = 'DELETE $endpoint';
    final sw = Stopwatch()..start();
    AppLogger.instance.debug(_tag, '→ $label');

    _warnIfTokenExpected(endpoint);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final res = await _client
          .delete(url, headers: _headers)
          .timeout(ApiConfig.receiveTimeout);
      sw.stop();
      AppLogger.instance.info(
        _tag,
        '← $label ${res.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return _handle(res, label);
    } on SocketException catch (e) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label no internet (${sw.elapsedMilliseconds}ms)',
        e,
      );
      return ApiResponse.err('No internet connection.', 0);
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label threw (${sw.elapsedMilliseconds}ms)',
        e,
        st,
      );
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> postMultipart(
    String endpoint,
    Map<String, String> fields,
    String? filePath,
    String fileFieldName, {
    String? token,
    String? phoneToken,
    MediaType? contentTypeOverride,
    Duration? timeout,
  }) {
    return _sendMultipart(
      'POST',
      endpoint,
      fields,
      filePath == null || filePath.isEmpty ? const [] : [filePath],
      fileFieldName,
      token: token,
      phoneToken: phoneToken,
      contentTypeOverride: contentTypeOverride,
      timeout: timeout,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> postMultipartFiles(
    String endpoint,
    Map<String, String> fields,
    List<String> filePaths,
    String fileFieldName, {
    String? token,
    String? phoneToken,
    MediaType? contentTypeOverride,
    Duration? timeout,
  }) {
    return _sendMultipart(
      'POST',
      endpoint,
      fields,
      filePaths,
      fileFieldName,
      token: token,
      phoneToken: phoneToken,
      contentTypeOverride: contentTypeOverride,
      timeout: timeout,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> putMultipart(
    String endpoint,
    Map<String, String> fields,
    String? filePath,
    String fileFieldName, {
    String? token,
    String? phoneToken,
  }) {
    return _sendMultipart(
      'PUT',
      endpoint,
      fields,
      filePath == null || filePath.isEmpty ? const [] : [filePath],
      fileFieldName,
      token: token,
      phoneToken: phoneToken,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> _sendMultipart(
    String method,
    String endpoint,
    Map<String, String> fields,
    List<String> filePaths,
    String fileFieldName, {
    String? token,
    String? phoneToken,
    MediaType? contentTypeOverride,
    Duration? timeout,
  }) async {
    final label = '$method(multipart) $endpoint';
    final sw = Stopwatch()..start();
    AppLogger.instance.debug(
      _tag,
      '→ $label fields=${fields.keys.toList()} files=${filePaths.length}',
    );

    _warnIfTokenExpected(endpoint);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      );

      // Deliberately NOT ApiConfig.defaultHeaders: that map carries
      // 'Content-Type': 'application/json', and forcing it onto a multipart
      // request makes Laravel ignore the boundary, so $request->hasFile()
      // returns false and image_url silently stays null. MultipartRequest sets
      // its own Content-Type (with boundary) at send() time.
      final headers = <String, String>{
        'Accept': 'application/json',
        'X-API-KEY': ?ApiConfig.apiSecretKey,
      };

      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : _token;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      final effectivePhoneToken = (phoneToken != null && phoneToken.isNotEmpty)
          ? phoneToken
          : _phoneToken;
      if (effectivePhoneToken != null && effectivePhoneToken.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = effectivePhoneToken;
      }

      if (method == 'PUT') {
        // Laravel method spoofing: POST body, real verb PUT.
        request.fields['_method'] = 'PUT';
      }

      request.headers.addAll(headers);
      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      // Attach every file in [filePaths]. TikTok photo posting needs the whole
      // carousel in one request, so this cannot be single-file only.
      var attached = 0;
      for (final path in filePaths) {
        if (path.isEmpty) continue;

        // Check the file actually exists before attaching it, so a stale temp
        // path from the picker/cropper produces a clear error instead of a
        // "successful" upload carrying nothing.
        if (!await File(path).exists()) {
          AppLogger.instance.error(_tag, '$label file missing at $path');
          return ApiResponse.err(
            'Faili la picha halikupatikana. Tafadhali chagua picha tena.',
            0,
          );
        }

        final contentType =
            contentTypeOverride ?? _resolveImageContentType(path);
        final file = await http.MultipartFile.fromPath(
          fileFieldName,
          path,
          contentType: contentType,
        );
        request.files.add(file);
        attached++;
        AppLogger.instance.debug(
          _tag,
          '$label attached "$fileFieldName" as ${contentType.mimeType}, ${file.length} bytes',
        );
      }

      if (attached == 0) {
        AppLogger.instance.error(_tag, '$label had no files to send.');
        return ApiResponse.err('Hakuna faili ya kutuma.', 0);
      }

      // Large uploads (a 1 GB video to TikTok) need far longer than the JSON
      // timeout; callers can pass their own.
      final streamedResponse = await request.send().timeout(
        timeout ?? ApiConfig.receiveTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);
      sw.stop();

      AppLogger.instance.info(
        _tag,
        '← $label ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return _handle(response, label);
    } on SocketException catch (e) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label no internet (${sw.elapsedMilliseconds}ms)',
        e,
      );
      return ApiResponse.err('No internet connection.', 0);
    } catch (e, st) {
      sw.stop();
      AppLogger.instance.error(
        _tag,
        '✗ $label threw (${sw.elapsedMilliseconds}ms)',
        e,
        st,
      );
      return ApiResponse.err('Error: $e', 0);
    }
  }

  // --------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------

  /// Endpoints that are called before (or instead of) having a session, so the
  /// absence of an Authorization header is expected rather than a warning.
  static bool _isPublicEndpoint(String endpoint) =>
      endpoint.startsWith('/auth/');

  /// Logs a missing token only where one is genuinely required.
  void _warnIfTokenExpected(String endpoint) {
    if (_token != null && _token!.isNotEmpty) return;
    if (_isPublicEndpoint(endpoint)) {
      AppLogger.instance.debug(
        _tag,
        '$endpoint is public, sending without a token.',
      );
      return;
    }
    AppLogger.instance.warn(_tag, '$endpoint sent without an auth token.');
  }

  Map<String, String> _headersWithOverrides(String? token, String? phoneToken) {
    final headers = _headers;

    final effectiveToken = (token != null && token.isNotEmpty) ? token : _token;
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveToken';
    } else {
      headers.remove('Authorization');
    }

    final effectivePhoneToken = (phoneToken != null && phoneToken.isNotEmpty)
        ? phoneToken
        : _phoneToken;
    if (effectivePhoneToken != null && effectivePhoneToken.isNotEmpty) {
      headers[ApiConfig.phoneTokenHeader] = effectivePhoneToken;
    }

    return headers;
  }

  /// Logs the body's shape rather than its contents: knowing which keys were
  /// sent is what you need when a request 422s, and it keeps PII and tokens
  /// out of the file.
  String _summarizeBody(Map<String, dynamic> body) {
    if (body.isEmpty) return '{}';
    final keys = body.keys
        .map((k) {
          final v = body[k];
          if (v == null) return '$k=null';
          if (v is String) return '$k=string(${v.length})';
          if (v is num || v is bool) return '$k=$v';
          if (v is List) return '$k=list(${v.length})';
          if (v is Map) return '$k=map(${v.length})';
          return '$k=${v.runtimeType}';
        })
        .join(', ');
    return '{$keys}';
  }

  String _excerpt(String body) {
    final trimmed = body.trim();
    if (trimmed.length <= _bodyExcerptLimit) return trimmed;
    return '${trimmed.substring(0, _bodyExcerptLimit)}… (+${trimmed.length - _bodyExcerptLimit} chars)';
  }

  ApiResponse<Map<String, dynamic>> _handle(http.Response res, String label) {
    try {
      _storeCookies(res.headers);

      // An HTML body means we hit a proxy/404 page instead of the API.
      if (res.headers['content-type']?.contains('text/html') == true) {
        AppLogger.instance.error(
          _tag,
          '← $label ${res.statusCode} returned HTML, not JSON (endpoint missing?)',
        );
        return ApiResponse.err(
          'API endpoint not found (HTML response)',
          res.statusCode,
        );
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final bool? successFlag = json['success'] as bool?;
        final String? statusFlag = json['status'] as String?;

        if (successFlag == false ||
            statusFlag == 'error' ||
            statusFlag == 'fail') {
          final message =
              (json['message'] as String?) ??
              (json['error'] as String?) ??
              'Request failed.';
          AppLogger.instance.warn(
            _tag,
            '← $label ${res.statusCode} reported failure: $message',
          );
          return ApiResponse.err(message, res.statusCode);
        }

        return ApiResponse.ok(json, res.statusCode);
      }

      Map<String, List<String>>? fieldErrors;
      final rawErrors = json['errors'];
      if (rawErrors is Map) {
        fieldErrors = rawErrors.map(
          (key, value) => MapEntry(
            key.toString(),
            (value is List)
                ? value.map((e) => e.toString()).toList()
                : [value.toString()],
          ),
        );
      }

      // Preserve any machine-readable context, e.g. TikTok's error code inside
      // `details`, so callers can branch on it instead of guessing from text.
      final rawDetails = json['details'];
      final details = rawDetails is Map
          ? rawDetails.map((k, v) => MapEntry(k.toString(), v))
          : null;

      final message =
          (json['message'] as String?) ??
          (json['error'] as String?) ??
          (fieldErrors != null && fieldErrors.isNotEmpty
              ? fieldErrors.values.first.first
              : null) ??
          'Request failed.';

      AppLogger.instance.warn(
        _tag,
        '← $label ${res.statusCode} failed: $message'
        '${fieldErrors != null ? ' fields=${fieldErrors.keys.toList()}' : ''}'
        '${details != null ? ' details=${details.keys.toList()}' : ''}',
      );

      return ApiResponse.err(
        message,
        res.statusCode,
        fieldErrors: fieldErrors,
        details: details,
      );
    } catch (e) {
      AppLogger.instance.error(
        _tag,
        '← $label ${res.statusCode} body could not be parsed: '
        '${_excerpt(res.body)}',
        e,
      );
      return ApiResponse.err('Failed to parse response.', res.statusCode);
    }
  }
}
