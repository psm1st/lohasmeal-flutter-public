

import 'package:app_links/app_links.dart';

DeeplinkService deeplinkService = DeeplinkService();
typedef DeepLinkCallback = void Function(Uri);
class DeeplinkService {
  static final DeeplinkService _instance = DeeplinkService._privateConstructor();

  factory DeeplinkService(){
    return _instance;
  }

  late AppLinks _appLinks;

  DeeplinkService._privateConstructor() {
    _appLinks = AppLinks();
  }

  Future<Uri?> getInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null && uri.scheme.toLowerCase() == 'cokloghost') {
      return null;
    }
    return uri;
  }

  void listen(DeepLinkCallback callback) {
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme.toLowerCase() == 'cokloghost') return;
      callback(uri);
    });
  }
}