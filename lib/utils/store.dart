
import 'package:shared_preferences/shared_preferences.dart';

Store store = Store();
class Store{
  late SharedPreferences _values;
  bool _initFlag = false;
  static final Store _instance = Store._privateConstructor();

  Store._privateConstructor() {
    init();
  }

  init() async {
    if(!_initFlag) {
      _values = await SharedPreferences.getInstance();
      _initFlag = true;
    }
  }

  factory Store()  {
    return _instance;
  }

  set(String key, dynamic value) async {
    if(value is int ) {
      return await _values.setInt(key, value);
    } else if (value is bool) {
      return await _values.setBool(key, value);
    } else if (value is double) {
      return await _values.setDouble(key, value);
    } else {
      return await _values.setString(key, value);
    }
  }

  T get<T>(String key) {
    return _values.get(key) as T;
  }

  remove(String key) async {
    return await _values.remove(key);
  }
}