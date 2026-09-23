package com.lohasmeal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterChannel.initChannel(this, flutterEngine)
    }

    override fun onDestroy() {
        FlutterChannel.getInstance().invokeMethod("onDestroy",null)
        Thread.sleep(200)
        super.onDestroy()
    }
}
