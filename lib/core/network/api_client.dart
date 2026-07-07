import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.traceId,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final String? traceId;
  final dynamic details;

  @override
  String toString() => message;
}

class DownloadedFile {
  const DownloadedFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;
  Future<bool> Function()? onUnauthorized;

  void setAccessToken(String? value) => _accessToken = value;

  /// Resuelve correctamente las tres formas de URL que puede devolver la API:
  ///
  /// * Ruta relativa al prefijo: `/reports/{id}/download`.
  /// * Ruta absoluta del API: `/api/v1/reports/{id}/download`.
  /// * URL completa: `https://api.example.com/api/v1/...`.
  ///
  /// Antes se concatenaba siempre [AppConfig.apiBaseUrl] con [path]. Cuando el
  /// backend devolvía `/api/v1/reports/...`, el resultado contenía el prefijo
  /// duplicado: `/api/v1/api/v1/reports/...`, provocando un HTTP 404 al
  /// descargar el reporte.
  Uri resolveUri(String path, [Map<String, String>? query]) {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      return parsed.replace(
        queryParameters: query == null || query.isEmpty
            ? parsed.queryParameters.isEmpty
                ? null
                : parsed.queryParameters
            : {...parsed.queryParameters, ...query},
      );
    }

    final base = Uri.parse(AppConfig.apiBaseUrl);

    if (path.startsWith('/api/')) {
      return Uri(
        scheme: base.scheme,
        userInfo: base.userInfo,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: path,
        queryParameters: query == null || query.isEmpty ? null : query,
      );
    }

    final normalizedBase = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$normalizedBase/$normalizedPath').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Uri _uri(String path, [Map<String, String>? query]) => resolveUri(path, query);

  Map<String, String> _headers({
    required bool authenticated,
    bool json = true,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (authenticated && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<http.Response> _withRefresh(
    Future<http.Response> Function() request, {
    required bool authenticated,
    required bool retry,
  }) async {
    var response = await request();
    if (response.statusCode == 401 &&
        authenticated &&
        retry &&
        onUnauthorized != null &&
        await onUnauthorized!.call()) {
      response = await request();
    }
    return response;
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final response = await _withRefresh(
      () => _client.get(
        _uri(path, query),
        headers: _headers(authenticated: authenticated),
      ),
      authenticated: authenticated,
      retry: retryOnUnauthorized,
    );
    return _decode(response);
  }

  Future<dynamic> postJson(
    String path,
    Map<String, dynamic>? body, {
    Map<String, String>? extraHeaders,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    Future<http.Response> call() => _client.post(
          _uri(path),
          headers: {
            ..._headers(authenticated: authenticated),
            ...?extraHeaders,
          },
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
    return _decode(
      await _withRefresh(
        call,
        authenticated: authenticated,
        retry: retryOnUnauthorized,
      ),
    );
  }

  Future<dynamic> putJson(
    String path,
    Map<String, dynamic>? body, {
    bool authenticated = true,
  }) async {
    Future<http.Response> call() => _client.put(
          _uri(path),
          headers: _headers(authenticated: authenticated),
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
    return _decode(
      await _withRefresh(call, authenticated: authenticated, retry: true),
    );
  }

  Future<dynamic> postFile(
    String path, {
    required String filename,
    required Uint8List bytes,
    bool authenticated = true,
  }) async {
    Future<http.Response> call() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(
        _headers(authenticated: authenticated, json: false),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      return http.Response.fromStream(await _client.send(request));
    }

    return _decode(
      await _withRefresh(call, authenticated: authenticated, retry: true),
    );
  }

  Future<void> delete(String path, {bool authenticated = true}) async {
    Future<http.Response> call() => _client.delete(
          _uri(path),
          headers: _headers(authenticated: authenticated),
        );
    final response = await _withRefresh(
      call,
      authenticated: authenticated,
      retry: true,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
  }

  Future<DownloadedFile> download(
    String path, {
    String fallbackName = 'archivo.bin',
  }) async {
    Future<http.Response> call() => _client.get(
          _uri(path),
          headers: _headers(authenticated: true, json: false),
        );
    final response = await _withRefresh(
      call,
      authenticated: true,
      retry: true,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }

    if (response.bodyBytes.isEmpty) {
      throw const ApiException(
        'El servicio respondió sin contenido para descargar.',
        code: 'REPORT_EMPTY_FILE',
      );
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final utf8Match = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    final basicMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    final encodedName = utf8Match?.group(1);
    final filename = encodedName != null
        ? Uri.decodeComponent(encodedName)
        : basicMatch?.group(1) ?? fallbackName;

    return DownloadedFile(
      bytes: response.bodyBytes,
      filename: filename,
      contentType:
          response.headers['content-type'] ?? 'application/octet-stream',
    );
  }

  dynamic _decode(http.Response response) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        payload = response.body;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      final legacy = payload['error'];
      if (legacy is Map<String, dynamic>) {
        throw ApiException(
          legacy['message']?.toString() ?? 'Error del servicio.',
          code: legacy['code']?.toString(),
          statusCode: response.statusCode,
          details: legacy['details'],
        );
      }
      throw ApiException(
        (payload['detail'] ?? payload['title'] ?? 'Error del servicio.')
            .toString(),
        code: payload['code']?.toString(),
        statusCode: response.statusCode,
        traceId: payload['traceId']?.toString(),
        details: payload['errors'],
      );
    }
    throw ApiException(
      'Error HTTP ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }
}
