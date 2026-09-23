import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:lohasmeal/widget/page/index/webview_ctl.dart';


class Webview extends GetView<WebviewCtl> {
  const Webview({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          key: super.key,
          onPermissionRequest: controller.onPermissionRequest,
          onGeolocationPermissionsShowPrompt: controller
              .onGeolocationPermissionsShowPrompt,
          initialUrlRequest: controller.initialUrlRequest,
          initialSettings: controller.settings,
          pullToRefreshController: controller.pullToRefreshController,
          onWebViewCreated: controller.onViewCreated,
          onLoadStart: controller.onLoadStop,
          onLoadStop: controller.onLoadStop,
          onReceivedError: controller.onReceivedError,
          onConsoleMessage: controller.onConsoleMessage,
          onProgressChanged: controller.onProgressChanged,
          shouldOverrideUrlLoading: controller.shouldOverrideUrlLoading,
          onUpdateVisitedHistory: controller.onUpdateVisitedHistory,
        ),
        Obx(() =>
            Visibility(
                visible: controller.showLoading.value,
                child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(minHeight: 0.5))
            ))
      ],);
  }
}
