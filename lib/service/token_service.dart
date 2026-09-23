import 'package:lohasmeal/utils/store.dart';

TokenService tokenService = TokenService();
class TokenService {

  TokenService._privateConstructor();

  static final TokenService _instance = TokenService._privateConstructor();

  factory TokenService(){
    return _instance;
  }

  static String? _asToken(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      var trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed == 'null' || trimmed == 'undefined') return null;
      trimmed = trimmed.replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is Map) {
      final map = raw.cast<dynamic, dynamic>();
      return _asToken(
        map['accessToken'] ??
            map['access_token'] ??
            map['refreshToken'] ??
            map['refresh_token'] ??
            map['token'] ??
            map['shopAccessToken'] ??
            map['shopRefreshToken'],
      );
    }
    if (raw is List && raw.isNotEmpty) return _asToken(raw.first);
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  updateShopAccessToken(dynamic shopAccessToken) async {
    final token = _asToken(shopAccessToken);
    if(token == null) {
      store.remove("shopAccessToken");
    } else {
      await store.set("shopAccessToken", token);
    }
  }

  updateShopRefreshToken(dynamic shopRefreshToken) async {
    final token = _asToken(shopRefreshToken);
    if(token == null) {
      store.remove("shopRefreshToken");
    } else {
      await store.set("shopRefreshToken", token);
    }
  }

  String getShopAccessToken() {
    return store.get("shopAccessToken") ?? "";
  }


  String getShopRefreshToken() {
    return store.get("shopRefreshToken") ?? "";
  }

  Future<void> clearShopSession() async {
    await updateShopAccessToken('');
    await updateShopRefreshToken('');
  }
}
