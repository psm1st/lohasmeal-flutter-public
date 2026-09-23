import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lohasmeal/widget/page/index/webview.dart';
import 'package:lohasmeal/widget/page/index/webview_ctl.dart';


class WebviewLayout extends StatelessWidget {
  const WebviewLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if(!didPop) {
          webviewCtl.backButtonPress();
        }
      },
      child: Container(
          color: Colors.white,
          child: SafeArea(
            maintainBottomViewPadding: true,
            child: Scaffold(
              resizeToAvoidBottomInset: !Platform.isIOS,
              body: const Webview(),
            ) ),
          )
    );
  }
}
