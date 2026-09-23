import 'package:coklog_module/coklog_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:lohasmeal/widget/page/index/webview_ctl.dart';
import 'package:lohasmeal/widget/page/index/webview_layout.dart';

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialBinding: BindingsBuilder(() {
        webviewCtl = Get.put(WebviewCtl());
      }),
      getPages: [
        GetPage(name: "/", page: () => const WebviewLayout()),
        GetPage(
          name: "/coklog",
          page: () {
            final args = Get.arguments;
            String? categoryId;
            if (args is Map && args['categoryId'] is String) {
              categoryId = args['categoryId'] as String;
            }
            return CoklogMiniappPage(initialCategoryId: categoryId);
          },
        ),
      ],
      initialRoute: '/',
    );
  }
}
