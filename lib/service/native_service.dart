import 'package:flutter/services.dart';
import 'dart:io';


NativeService nativeService = NativeService();
class NativeService {
  static final NativeService _instance = NativeService._privateConstructor();
  factory NativeService() {
    return _instance;
  }

  final MethodChannel _commonChannel = const MethodChannel('/common');
  final MethodChannel _androidChannel = const MethodChannel('/android');
  final MethodChannel _iosChannel = const MethodChannel('/ios');
  final Map<String,Function> _commonMethodHandler = {};
  final Map<String,Function> _androidMethodHandler = {};
  final Map<String,Function> _iosMethodHandler = {};

  NativeService._privateConstructor(){
    _commonChannel.setMethodCallHandler((MethodCall call) async {
      if(call.arguments == null) {
        _commonMethodHandler[call.method]?.call();
      }else {
        _commonMethodHandler[call.method]?.call(call.arguments);
      }
    });

    if(Platform.isIOS) {
      _iosChannel.setMethodCallHandler((MethodCall call) async {
        if(call.arguments == null) {
          _iosMethodHandler[call.method]?.call();
        }else {
          _iosMethodHandler[call.method]?.call(call.arguments);
        }
      });
    }

    if(Platform.isAndroid) {
      _androidChannel.setMethodCallHandler((MethodCall call) async {
        if(call.arguments == null) {
          _androidMethodHandler[call.method]?.call();
        }else {
          _androidMethodHandler[call.method]?.call(call.arguments);
        }
      });
    }
  }

  addMethodHandler(String event, Function method) {
    _commonMethodHandler[event] = method;
  }

  addAndroidMethodHandler(String event, Function method) {
    if(Platform.isAndroid) {
      _androidMethodHandler[event] = method;
    }
  }

  addIosMethodHandler(String event, Function method) {
    if(Platform.isIOS) {
      _iosMethodHandler[event] = method;
    }
  }

  removeMethodHandler(String event) {
    _commonMethodHandler.remove(event);
  }

  removeIosMethodHandler(String event) {
    if(Platform.isIOS) {
      _iosMethodHandler.remove(event);
    }
  }

  removeAndroidMethodHandler(String event) {
    if(Platform.isAndroid) {
      _androidMethodHandler.remove(event);
    }
  }

  call(String event, [ dynamic arguments ]) {
    return _commonChannel.invokeMethod(event, arguments);
  }

  callAndroid(String event, [ dynamic arguments ]) {
    if(Platform.isAndroid) {
      return _androidChannel.invokeMethod(event, arguments);
    }
    return null;
  }

  callIos(String event, [ dynamic arguments ]) {
    if(Platform.isIOS) {
      return _iosChannel.invokeMethod(event, arguments);
    }
    return null;
  }
}
