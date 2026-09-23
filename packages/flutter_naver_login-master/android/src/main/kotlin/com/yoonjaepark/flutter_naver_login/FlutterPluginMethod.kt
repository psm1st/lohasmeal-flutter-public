package com.yoonjaepark.flutter_naver_login

sealed class FlutterPluginMethod(val methodName: String) {
    object InitSdk : FlutterPluginMethod("initSdk")
    object LogIn : FlutterPluginMethod("logIn")
    object LogOut : FlutterPluginMethod("logOut")
    object LogOutAndDeleteToken : FlutterPluginMethod("logoutAndDeleteToken")
    object GetCurrentAccount : FlutterPluginMethod("getCurrentAccount")
    object GetCurrentAccessToken : FlutterPluginMethod("getCurrentAccessToken")
    object RefreshAccessTokenWithRefreshToken :
        FlutterPluginMethod("refreshAccessTokenWithRefreshToken")

    companion object {
        fun fromMethodName(name: String?): FlutterPluginMethod? {
            return when (name) {
                InitSdk.methodName -> InitSdk
                LogIn.methodName -> LogIn
                LogOut.methodName -> LogOut
                LogOutAndDeleteToken.methodName -> LogOutAndDeleteToken
                GetCurrentAccount.methodName -> GetCurrentAccount
                GetCurrentAccessToken.methodName -> GetCurrentAccessToken
                RefreshAccessTokenWithRefreshToken.methodName -> RefreshAccessTokenWithRefreshToken
                else -> null
            }
        }
    }
}