import 'package:flutter_dotenv/flutter_dotenv.dart';

Config config = Config();
class Config {
  bool _initFlag = false;

  static final Config _instance = Config._privateConstructor();

  factory Config() {
    return _instance;
  }

  Config._privateConstructor() {}

  init() async {
    if (!_initFlag) {
      const envFileName = String.fromEnvironment(
          'env', defaultValue: '.env');
      await dotenv.load(fileName: 'assets/config/$envFileName');
      _initFlag = true;
    }
  }

  String get(String name, {String? fallback}) {
    return dotenv.get(name,fallback: fallback);
  }
}