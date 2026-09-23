import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomOption {
  static var systemAppBarOption = const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light);
}