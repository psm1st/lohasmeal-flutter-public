import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

class MobidocUtil {

  static rgbStringToColor(String rgbString) {
    var rgb = rgbString.replaceAll(RegExp('[^0-9,]'), "");
    var list = rgb.split(',');
    return Color.fromRGBO(
        int.parse(list[0]), int.parse(list[1]), int.parse(list[2]), 1.0);
  }

  static showDebugDialog(String title, String msg) {
    return Get.dialog(
      AlertDialog(
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: Text(
          "MSG : $msg",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
              child: const Text('확인'),
              onPressed: () => Get.back()
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  static showDebugToast(String msg) {
    Fluttertoast.showToast(
        msg: msg,
        backgroundColor: Colors.black,
        textColor: Colors.white
    );
  }
}