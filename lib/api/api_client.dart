import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Base URL of the Saku API (Hono on Vercel). Override with
/// `--dart-define=SAKU_API_URL=http://10.0.2.2:5173/api` for local dev.
const kApiBaseUrl = String.fromEnvironment('SAKU_API_URL', defaultValue: 'https://saku-web-one.vercel.app/api');

/// Error from the API, parsed from ProblemDetails `{ title, status, errors? }`.
class ApiException implements Exception {
  ApiException(this.status, this.title, {this.errors = const {}, this.extra = const {}});

  final int status;
  final String title;
  final Map<String, List<String>> errors;
  final Map<String, dynamic> extra;

  /// First field error, falling back to the title.
  String get message => errors.values.expand((e) => e).firstOrNull ?? title;

  String? fieldError(String field) => errors[field]?.firstOrNull;

  @override
  String toString() => 'ApiException($status, $title)';
}

/// Persists the session cookie. Replaceable in tests.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureTokenStore implements TokenStore {
  static const _key = 'saku_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? token) =>
      token == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: token);
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String? token) async => _token = token;
}

/// Thin HTTP wrapper. The server authenticates with the `saku_token` cookie
/// (no Bearer), so the cookie is captured from `Set-Cookie` and replayed.
/// Mutations need `X-Requested-With: saku` (CSRF guard).
class ApiClient {
  ApiClient({http.Client? httpClient, TokenStore? tokenStore, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        tokenStore = tokenStore ?? SecureTokenStore(),
        baseUrl = baseUrl ?? kApiBaseUrl;

  final http.Client _http;
  final TokenStore tokenStore;
  final String baseUrl;

  String? _token;
  bool _loaded = false;

  /// Called on any 401 for an authenticated request (session expired).
  void Function()? onUnauthorized;

  static final _cookieRe = RegExp(r'saku_token=([^;,]*)');
  static const _timeout = Duration(seconds: 30);

  Future<bool> hasToken() async {
    await _ensureLoaded();
    return _token != null && _token!.isNotEmpty;
  }

  Future<void> clearToken() async {
    _token = null;
    await tokenStore.write(null);
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _token = await tokenStore.read();
    _loaded = true;
  }

  Future<T> get<T>(String path, {Map<String, String?>? query}) => _send<T>('GET', path, query: query);
  Future<T> post<T>(String path, [Object? body]) => _send<T>('POST', path, body: body);
  Future<T> put<T>(String path, [Object? body]) => _send<T>('PUT', path, body: body);
  Future<T> delete<T>(String path) => _send<T>('DELETE', path);

  Future<T> _send<T>(String method, String path, {Object? body, Map<String, String?>? query}) async {
    await _ensureLoaded();
    final q = {for (final e in (query ?? {}).entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);

    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['X-Requested-With'] = 'saku';
    if (_token != null && _token!.isNotEmpty) req.headers['Cookie'] = 'saku_token=$_token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'Server tidak merespons. Coba lagi.');
    } on Exception {
      throw ApiException(0, 'Tidak ada koneksi internet.');
    }

    final setCookie = res.headers['set-cookie'];
    if (setCookie != null) {
      final m = _cookieRe.firstMatch(setCookie);
      if (m != null) {
        _token = m.group(1)!.isEmpty ? null : m.group(1);
        await tokenStore.write(_token);
      }
    }

    if (res.statusCode == 204 || res.body.isEmpty) {
      if (res.statusCode >= 400) throw ApiException(res.statusCode, 'Terjadi kesalahan.');
      return null as T;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw ApiException(res.statusCode, res.statusCode >= 500 ? 'Server sedang bermasalah.' : 'Respons server tidak valid.');
    }

    if (res.statusCode >= 400) {
      final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final errors = <String, List<String>>{};
      final raw = map['errors'];
      if (raw is Map) {
        raw.forEach((k, v) => errors['$k'] = v is List ? v.map((e) => '$e').toList() : ['$v']);
      }
      final extra = Map<String, dynamic>.of(map)..removeWhere((k, _) => k == 'title' || k == 'status' || k == 'errors');
      final err = ApiException(res.statusCode, (map['title'] as String?) ?? 'Terjadi kesalahan.', errors: errors, extra: extra);
      final isAuthCall = path.startsWith('/auth/login') || path.startsWith('/auth/setup') || path.startsWith('/auth/status');
      if (res.statusCode == 401 && !isAuthCall) {
        await clearToken();
        onUnauthorized?.call();
      }
      throw err;
    }
    return decoded as T;
  }
}
