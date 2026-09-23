import 'dart:convert';
import 'dart:io';

import 'package:coklog_module/coklog_module.dart';
import 'package:flutter/foundation.dart';
import 'package:lohasmeal/service/host/shop_session.dart';

/// Issues miniapp access tokens via api-shop (shop Bearer, no request signing).
class MiniappTokenService {
  MiniappTokenService._();
  static final MiniappTokenService instance = MiniappTokenService._();

  ShopSession get _shop => ShopSession.instance;

  Future<MiniappTokenResult?> issueToken({
    required String appId,
    required Map<String, dynamic> clientPublicKey,
  }) async {
    if (!await _shop.ensureShopSession()) return null;

    final base = _shop.shopApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/v1/miniapp/auth/token');
    final access = _shop.accessToken.trim();
    if (access.isEmpty) return null;

    final body = jsonEncode({
      'appId': appId,
      'clientPublicKey': {
        'kty': clientPublicKey['kty'],
        'crv': clientPublicKey['crv'],
        'x': clientPublicKey['x'],
        'y': clientPublicKey['y'],
      },
    });

    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        access.startsWith(RegExp(r'Bearer\s+', caseSensitive: false))
            ? access
            : 'Bearer $access',
      );
      request.add(utf8.encode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'miniapp token issue failed status=${response.statusCode} body=${text.length > 200 ? text.substring(0, 200) : text}',
        );
        return null;
      }
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final data = parsed['data'];
      if (data is! Map) return null;
      final token = data['accessToken']?.toString().trim() ?? '';
      if (token.isEmpty) return null;
      final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 900;
      final memberId = (data['memberId'] as num?)?.toInt();
      return MiniappTokenResult(
        accessToken: token,
        expiresIn: expiresIn,
        memberId: memberId,
      );
    } catch (e) {
      debugPrint('miniapp token issue error: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
