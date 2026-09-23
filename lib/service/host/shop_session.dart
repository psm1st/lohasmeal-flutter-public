import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lohasmeal/constants/config.dart';
import 'package:lohasmeal/service/token_service.dart';
import 'package:lohasmeal/utils/store.dart';

/// Shop IdP session. Shared by every miniapp WebView.
class ShopSession {
  ShopSession._();
  static final ShopSession instance = ShopSession._();

  String get shopApiBaseUrl =>
      config.get('WEB_HOST', fallback: 'https://lohasmeal.com');

  String get accessToken => tokenService.getShopAccessToken();

  String get refreshToken => tokenService.getShopRefreshToken();

  bool get hasUsableAccessToken {
    final token = accessToken.trim();
    if (token.isEmpty) return false;
    // Non-JWT / unparseable tokens must not open coklog.
    if (_jwtPayload(token) == null) return false;
    return !_isJwtExpired(token);
  }

  String? get usableRefreshToken {
    final refresh = refreshToken.trim();
    if (refresh.isEmpty) return null;
    if (refresh == accessToken.trim()) return null;
    return refresh;
  }

  int? memberIdFromAccessToken() {
    final token = accessToken.trim();
    if (token.isEmpty) return null;
    final map = _jwtPayload(token);
    if (map == null) return null;
    final id = map['memberId'] ?? map['member_id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse('$id');
  }

  Future<bool> ensureShopSession() async {
    await store.init();
    if (hasUsableAccessToken) return true;
    await refreshAccessToken();
    return hasUsableAccessToken;
  }

  Future<bool> refreshAccessToken() async {
    final refresh = usableRefreshToken;
    if (refresh == null) return false;

    final base = shopApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/v1/auth/access-token');
    final shopRefresh =
        refresh.startsWith(RegExp(r'Bearer\s+', caseSensitive: false))
            ? refresh
            : 'Bearer $refresh';
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('shopRefreshToken', shopRefresh);
      final access = accessToken.trim();
      if (access.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          access.startsWith(RegExp(r'Bearer\s+', caseSensitive: false))
              ? access
              : 'Bearer $access',
        );
      }
      request.add(utf8.encode('{}'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('ShopSession refresh HTTP ${response.statusCode}: $body');
        return false;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final map = decoded.cast<String, dynamic>();
      if (map['code']?.toString() == '40199') return false;
      final data = map['data'];
      final source = data is Map ? data.cast<String, dynamic>() : map;
      final next = (source['accessToken'] ?? source['access_token'])?.toString();
      if (next == null || next.trim().isEmpty) return false;
      await tokenService.updateShopAccessToken(next);
      return true;
    } catch (e) {
      debugPrint('ShopSession refresh error: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  static Map<String, dynamic>? _jwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final decoded = jsonDecode(utf8.decode(base64Decode(payload)));
      if (decoded is! Map) return null;
      return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static bool _isJwtExpired(String token, {int skewSec = 30}) {
    final exp = _jwtPayload(token)?['exp'];
    final expSec = exp is int
        ? exp
        : exp is num
            ? exp.toInt()
            : int.tryParse('$exp');
    if (expSec == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expSec <= now + skewSec;
  }
}
