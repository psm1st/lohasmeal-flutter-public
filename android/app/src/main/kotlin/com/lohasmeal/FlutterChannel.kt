package com.lohasmeal

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class FlutterChannel private constructor(
    private val flutterActivity: FlutterActivity,
    engine: FlutterEngine
) {
    private val androidChannel: MethodChannel
    private val commonChannel: MethodChannel


    companion object {
        private lateinit var instance: FlutterChannel
        fun initChannel(activity: FlutterActivity, engine: FlutterEngine) {
            instance = FlutterChannel(activity,engine)
        }
        fun getInstance(): FlutterChannel {
            return instance
        }
    }
    init {
        this.commonChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "/common")
        this.androidChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "/android")

        androidChannel.setMethodCallHandler {
                call, result ->
            when (call.method) {
                "market" -> {
                    val url: String = call.argument("url")!!
                    flutterActivity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(null)
                }
                "intent" -> {
                    val url: String = call.argument("url")!!
                    val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                    val fallback = runIntent(url, intent)
                    result.success(fallback)
                }
                "focusWebView" -> {
                    focusInAppWebView()
                    result.success(null)
                }
                else -> {
                    Log.e("Flutter Error", "error setMethodCallHandler $call")
                    result.notImplemented()
                }
            }
        }
    }

    private fun focusInAppWebView() {
        // Hybrid composition already shows IME when an HTML input is focused.
        // Do NOT call showSoftInput/restartInput here — that opens the keyboard on
        // WebView create/home entry, and restartInput resets IME type while typing.
        val webView = findWebView(flutterActivity.window.decorView) ?: return
        webView.isFocusable = true
        webView.isFocusableInTouchMode = true
        if (!webView.hasFocus()) {
            webView.requestFocus()
        }
    }

    private fun findWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findWebView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun runIntent(url: String, intent: Intent): String? {
        try {
            // 실행 가능한 앱이 있으면 앱 실행
            if (intent.resolveActivity(flutterActivity.packageManager) != null) {
                flutterActivity.startActivity(intent)
                return null;
            }
            // 실행 가능한 앱이 없으면 플레이 스토어 실행
            else if (intent.`package` != null) {
                flutterActivity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + intent.`package`)))
                return null;
            }

            // Fallback URL이 있으면 현재 웹뷰에 로딩
            val fallbackUrl = intent.getStringExtra("browser_fallback_url")
            if (fallbackUrl != null) {
                return fallbackUrl
            }
        } catch (e: ActivityNotFoundException) {
            // 실행 가능한 앱이 없으면 플레이 스토어 실행
            if (intent.`package` != null) {
                intent.setData(Uri.parse("market://details?id=" + intent.`package`))
                flutterActivity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                return null;
            }
        }
        return null;
    }

    fun invokeMethod(method: String, params: Any?) {
        commonChannel.invokeMethod(method,params)
    }
}
