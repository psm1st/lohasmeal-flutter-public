import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:lohasmeal/service/native_service.dart';

class KakaoLoginResponse {
  bool result = false;
  WebUri? fallback;
}

class NaverLoginResponse {
  String? nickname;
  String? id;
  String? name;
  String? email;
  String? gender;
  String? age;
  String? birthday;
  String? mobile;

  static NaverLoginResponse of(NaverLoginResult result) {
    NaverLoginResponse response = NaverLoginResponse();
    response.id = result.account.id;
    response.nickname = result.account.nickname;
    response.name = result.account.name;
    response.email = result.account.email;
    response.gender = result.account.gender;
    response.age = result.account.age;
    response.birthday = result.account.birthday;
    response.mobile = result.account.mobile;
    return response;
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "nickname": nickname,
      "email": email,
      "mobile": mobile,
      "gender": gender,
      "age": age,
      "birthday": birthday,
    };

  }
}

SocialLoginService socialLoginService = SocialLoginService();
class SocialLoginService {
  static final SocialLoginService _instance = SocialLoginService._privateConstructor();

  factory SocialLoginService() {
    return _instance;
  }

  SocialLoginService._privateConstructor();


  Future<KakaoLoginResponse> kakaoLogin(WebUri uri)  async {
    KakaoLoginResponse response = KakaoLoginResponse();
    if(uri.scheme == "intent" && uri.toString().contains("com.kakao.talk.intent")) {
      response.result = true;
      var fallback = await nativeService
          .callAndroid("intent",
          <String, Object>{'url': uri.toString(), 'rawValue': uri.rawValue});

      //앱을 열지 않았을 경우 링크로 처리
      if (fallback != null) {
        response.fallback = WebUri.uri(Uri.parse(fallback));
      }
    }
    return response;
  }

  Future<NaverLoginResponse> naverLogin() async {
    NaverLoginResult result = await FlutterNaverLogin.logIn();
    NaverLoginResponse response = NaverLoginResponse.of(result);
    return response;
  }

  naverLogout(){
    FlutterNaverLogin.logOut();
  }
}