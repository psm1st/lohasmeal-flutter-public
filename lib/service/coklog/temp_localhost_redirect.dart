import 'dart:io';

/// Opt-in remap: `your-coklog-dev.example.com` → local Next (`:3000`).
///
/// Enable at run time:
/// `flutter run --dart-define=env=.env.dev --dart-define=COKLOG_LOCALHOST=true`
class TempCoklogLocalhostRedirect {
  TempCoklogLocalhostRedirect._();

  /// `--dart-define=COKLOG_LOCALHOST=true` (default: off → env URL 그대로)
  static const enabled = bool.fromEnvironment('COKLOG_LOCALHOST');

  static const devHost = 'your-coklog-dev.example.com';

  /// Android emulator reaches the host machine via `10.0.2.2`, not `localhost`.
  static String get localOrigin {
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  /// Remaps env URLs that target [devHost] to [localOrigin] (path/query preserved).
  static String resolve(String url) {
    if (!enabled || url.trim().isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    if (uri.host.toLowerCase() != devHost) return url;

    final local = Uri.parse(localOrigin);
    return uri
        .replace(
          scheme: local.scheme,
          host: local.host,
          port: local.hasPort ? local.port : null,
        )
        .toString();
  }

  static bool isDevCoklogHost(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return false;
    return uri.host.toLowerCase() == devHost;
  }
}
