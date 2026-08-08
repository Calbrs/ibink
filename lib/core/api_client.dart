import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import 'session.dart';

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
  final int statusCode;
  final bool success;

  const ApiResponse({
    this.data,
    this.error,
    this.fieldErrors,
    required this.statusCode,
    required this.success,
  });

  factory ApiResponse.ok(T data, int code) => ApiResponse(data: data, statusCode: code, success: true);

  factory ApiResponse.err(String msg, int code, {Map<String, List<String>>? fieldErrors}) =>
      ApiResponse(error: msg, fieldErrors: fieldErrors, statusCode: code, success: false);

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

  void setToken(String token) {
    _token = token;
    if (kDebugMode) {
      debugPrint('[ApiClient] Token set: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    }
  }

  void setPhoneToken(String token) {
    _phoneToken = token;
    if (kDebugMode) {
      debugPrint('[ApiClient] Phone token set: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    }
  }

  void clearPhoneToken() {
    _phoneToken = null;
    if (kDebugMode) debugPrint('[ApiClient] Phone token cleared');
  }

  void clearToken() {
    _token = null;
    _phoneToken = null;
    if (kDebugMode) debugPrint('[ApiClient] Tokens cleared');
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;
  bool get hasPhoneToken => _phoneToken != null && _phoneToken!.isNotEmpty;

  void restoreTokenFromSession() {
    final saved = Session.instance.token;
    if (saved != null && saved.isNotEmpty) {
      _token = saved;
      if (kDebugMode) debugPrint('[ApiClient] Token restored from session');
    }
    final savedPhoneToken = Session.instance.phoneToken;
    if (savedPhoneToken != null && savedPhoneToken.isNotEmpty) {
      _phoneToken = savedPhoneToken;
      if (kDebugMode) debugPrint('[ApiClient] Phone token restored from session');
    }
  }

  void ensureTokenIsSet() {
    final session = Session.instance;

    if (session.token != null && session.token!.isNotEmpty) {
      if (_token == null || _token!.isEmpty) {
        _token = session.token;
        if (kDebugMode) {
          debugPrint('[ApiClient] Token restored from session: ${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}...');
        }
      }
    }

    if (session.phoneToken != null && session.phoneToken!.isNotEmpty) {
      if (_phoneToken == null || _phoneToken!.isEmpty) {
        _phoneToken = session.phoneToken;
        if (kDebugMode) debugPrint('[ApiClient] Phone token restored from session');
      }
    }

    if (kDebugMode) {
      debugPrint('[ApiClient] Token status: hasToken=${_token != null}, hasPhoneToken=${_phoneToken != null}');
    }
  }

  Map<String, String> get _headers {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
      if (kDebugMode) {
        debugPrint('[ApiClient] Adding Authorization header: Bearer ${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}...');
      }
    } else {
      if (kDebugMode) debugPrint('[ApiClient] No token available for headers');
    }

    if (_phoneToken != null && _phoneToken!.isNotEmpty) {
      headers[ApiConfig.phoneTokenHeader] = _phoneToken!;
    }

    return headers;
  }

  Future<ApiResponse<Map<String, dynamic>>> get(String endpoint) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (kDebugMode) debugPrint('[ApiClient] GET $url');
      final res = await _client
          .get(url, headers: _headers)
          .timeout(ApiConfig.receiveTimeout);
      return _handle(res);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
    String? phoneToken,
  }) async {
    try {
      final headers = Map<String, String>.from(ApiConfig.defaultHeaders);

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else if (_token != null && _token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_token';
      }

      if (phoneToken != null && phoneToken.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = phoneToken;
      } else if (_phoneToken != null && _phoneToken!.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = _phoneToken!;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final jsonBody = jsonEncode(body);

      if (kDebugMode) {
        debugPrint('[ApiClient] POST $url');
        debugPrint('[ApiClient] Body: $jsonBody');
        debugPrint('[ApiClient] Headers: ${headers.keys}');
      }

      final res = await _client
          .post(url, headers: headers, body: jsonBody)
          .timeout(ApiConfig.receiveTimeout);

      return _handle(res);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (kDebugMode) debugPrint('[ApiClient] PUT $url');
      final res = await _client
          .put(url, headers: _headers, body: jsonEncode(body))
          .timeout(ApiConfig.receiveTimeout);
      return _handle(res);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (kDebugMode) debugPrint('[ApiClient] PATCH $url');
      final res = await _client
          .patch(url, headers: _headers, body: jsonEncode(body))
          .timeout(ApiConfig.receiveTimeout);
      return _handle(res);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(String endpoint) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (kDebugMode) debugPrint('[ApiClient] DELETE $url');
      final res = await _client
          .delete(url, headers: _headers)
          .timeout(ApiConfig.receiveTimeout);
      return _handle(res);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
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
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[ApiClient] postMultipart - endpoint: $endpoint');
        debugPrint('[ApiClient] postMultipart - fields: $fields');
        debugPrint('[ApiClient] postMultipart - filePath: $filePath');
        debugPrint('[ApiClient] postMultipart - has token: ${_token != null}');
        if (_token != null) {
          debugPrint('[ApiClient] postMultipart - token: ${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}...');
        }
      }

      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$endpoint'));

      // FIX: HAPO AWALI tulikuwa tunachanganya ApiConfig.defaultHeaders
      // (ambayo ina 'Content-Type': 'application/json') moja kwa moja
      // kwenye request.headers ya MultipartRequest. Hii ilikuwa
      // ikisababisha Laravel kutafsiri request kama JSON badala ya
      // multipart/form-data - hivyo $request->hasFile('image') ilikuwa
      // ikirudisha false KIMYA KIMYA, na image_url ilibaki null hata kama
      // picha ilikuwa imeambatanishwa vizuri kwenye request. Tunaweka
      // HEADERS MAALUM za multipart hapa (bila Content-Type), na
      // kumwachia http.MultipartRequest aweke boundary yake mwenyewe
      // wakati wa .send().
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        if (kDebugMode) debugPrint('[ApiClient] Using provided token');
      } else if (_token != null && _token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_token';
        if (kDebugMode) debugPrint('[ApiClient] Using stored token');
      } else {
        if (kDebugMode) debugPrint('[ApiClient] WARNING: No token available for multipart request!');
      }

      if (phoneToken != null && phoneToken.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = phoneToken;
      } else if (_phoneToken != null && _phoneToken!.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = _phoneToken!;
      }

      if (kDebugMode) {
        debugPrint('[ApiClient] Multipart headers: ${headers.keys}');
        if (headers.containsKey('Authorization')) {
          debugPrint('[ApiClient] Auth header: ${headers['Authorization']!.substring(0, headers['Authorization']!.length > 30 ? 30 : headers['Authorization']!.length)}...');
        }
      }

      request.headers.addAll(headers);

      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      if (filePath != null && filePath.isNotEmpty) {
        // FIX: uhakiki wa uwepo halisi wa faili kwenye disk kabla ya
        // kujaribu kuliambatanisha - kama faili la muda la ImageCropper
        // limeshafutwa au path si sahihi, tunapata error ya wazi hapa
        // badala ya kutuma request "yenye picha" ambayo kwa kweli
        // haina faili lolote.
        final imageFile = File(filePath);
        if (!await imageFile.exists()) {
          if (kDebugMode) debugPrint('[ApiClient] WARNING: image file does not exist at $filePath');
          return ApiResponse.err('Faili la picha halikupatikana. Tafadhali chagua picha tena.', 0);
        }

        final contentType = _resolveImageContentType(filePath);
        if (kDebugMode) debugPrint('[ApiClient] File content type: ${contentType.mimeType}');

        final file = await http.MultipartFile.fromPath(
          fileFieldName,
          filePath,
          contentType: contentType,
        );
        request.files.add(file);
        if (kDebugMode) {
          debugPrint('[ApiClient] Attached file field "$fileFieldName", size: ${file.length} bytes');
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        debugPrint('[ApiClient] Multipart response status: ${response.statusCode}');
        debugPrint('[ApiClient] Multipart response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      }

      return _handle(response);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] Multipart error: $e');
      return ApiResponse.err('Error: $e', 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> putMultipart(
    String endpoint,
    Map<String, String> fields,
    String? filePath,
    String fileFieldName, {
    String? token,
    String? phoneToken,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[ApiClient] putMultipart - endpoint: $endpoint');
        debugPrint('[ApiClient] putMultipart - fields: $fields');
        debugPrint('[ApiClient] putMultipart - filePath: $filePath');
        debugPrint('[ApiClient] putMultipart - has token: ${_token != null}');
      }

      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$endpoint'));

      // FIX: sawa na postMultipart - usiweke 'Content-Type': 'application/json'
      // kwenye multipart request, vinginevyo Laravel haitatambua picha
      // iliyoambatanishwa (hasFile('image') inarudisha false).
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else if (_token != null && _token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_token';
      }

      if (phoneToken != null && phoneToken.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = phoneToken;
      } else if (_phoneToken != null && _phoneToken!.isNotEmpty) {
        headers[ApiConfig.phoneTokenHeader] = _phoneToken!;
      }

      request.headers.addAll(headers);
      request.fields['_method'] = 'PUT';

      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      if (filePath != null && filePath.isNotEmpty) {
        // FIX: uhakiki wa uwepo wa faili, kama ilivyo kwenye postMultipart.
        final imageFile = File(filePath);
        if (!await imageFile.exists()) {
          if (kDebugMode) debugPrint('[ApiClient] WARNING: image file does not exist at $filePath');
          return ApiResponse.err('Faili la picha halikupatikana. Tafadhali chagua picha tena.', 0);
        }

        final contentType = _resolveImageContentType(filePath);
        final file = await http.MultipartFile.fromPath(
          fileFieldName,
          filePath,
          contentType: contentType,
        );
        request.files.add(file);
        if (kDebugMode) {
          debugPrint('[ApiClient] Attached file field "$fileFieldName", size: ${file.length} bytes');
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        debugPrint('[ApiClient] Multipart PUT response status: ${response.statusCode}');
        debugPrint('[ApiClient] Multipart PUT response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      }

      return _handle(response);
    } on SocketException {
      return ApiResponse.err('No internet connection.', 0);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] Multipart PUT error: $e');
      return ApiResponse.err('Error: $e', 0);
    }
  }

  ApiResponse<Map<String, dynamic>> _handle(http.Response res) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final bool? successFlag = json['success'] as bool?;
        final String? statusFlag = json['status'] as String?;

        if (successFlag == false || statusFlag == 'error' || statusFlag == 'fail') {
          final message = (json['message'] as String?) ??
              (json['error'] as String?) ??
              'Request failed.';
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
            (value is List) ? value.map((e) => e.toString()).toList() : [value.toString()],
          ),
        );
      }

      final message = (json['message'] as String?) ??
          (json['error'] as String?) ??
          (fieldErrors != null && fieldErrors.isNotEmpty ? fieldErrors.values.first.first : null) ??
          'Request failed.';

      return ApiResponse.err(message, res.statusCode, fieldErrors: fieldErrors);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] Parse error: $e');
      return ApiResponse.err('Failed to parse response.', res.statusCode);
    }
  }
}