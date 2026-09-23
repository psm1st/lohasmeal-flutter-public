import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:store_redirect/store_redirect.dart';

AppService appService = AppService();
class AppService {
  AppService._privateConstructor();

  static final AppService _instance = AppService._privateConstructor();
  final InAppReview inAppReview = InAppReview.instance;

  factory AppService() {
    return _instance;
  }

  openAppReview() async {
    if (await inAppReview.isAvailable()) {
      inAppReview.requestReview();
    }
  }

  openSetting() async {
    await AppSettings.openAppSettings();
  }

  openAppStore({String? andId, String? iosId}) {
    StoreRedirect.redirect(androidAppId: andId,
        iOSAppId: iosId);
  }

  requestPermission(String granted) async {
    switch (granted) {
      case "Notification":
        return (await Permission.notification.request()).name;
      case "Camera":
        return (await Permission.camera.request()).name;
      case "Photos":
        return (await Permission.photos.request()).name;
      case "MediaLibrary":
        return (await Permission.mediaLibrary.request()).name;
      case "Location":
        return (await Permission.locationWhenInUse.request()).name;

    }
  }

  getPermission(String granted) async{
    switch (granted) {
      case "Notification":
        return (await Permission.notification.status).name;
      case "Camera":
        return (await Permission.camera.status).name;
      case "Photos":
        return (await Permission.photos.status).name;
      case "MediaLibrary":
        return (await Permission.mediaLibrary.status).name;
      case "Location":
        return (await Permission.locationWhenInUse.status).name;

    }
  }


  getAppVersion() async  {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String flutterVersion = packageInfo.version;
    return flutterVersion;
  }

  downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        return "download_failed: HTTP ${response.statusCode}";
      }
      await Gal.putImageBytes(response.bodyBytes);
      return "success";
    } catch (e) {
      return "error: $e";
    }
  }
}