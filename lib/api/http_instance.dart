import 'dart:convert';

import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:http/http.dart' as http;
import 'package:lohasmeal/utils/store.dart';



class HttpInstance {
  late String _host;

  final Map<String, String> _header = {
    'Content-type': 'application/json; charset=utf-8',
    'Accept': 'application/json; charset=utf-8',
    'Authorization' : '',
  };

  HttpInstance(String host) {
    _host = host;
  }


  //Token 가져 오는 방식 설정
  String _getToken() {
    String jwtToken = store.get("jwtToken") ?? '';
    return "Bearer $jwtToken";
  }

  void _addJwtToken() {
    _header['Authorization'] = _getToken();
  }

  String _removeFirstSlash(String uri) {
    while (uri.startsWith("/")) {
      uri = uri.replaceFirst('/', '');
    }
    return uri;
  }

  T? _result<T>(http.Response? response) {
    if (response?.statusCode == 200) {
      print("object ${utf8.decode(response!.bodyBytes).toString()}");
      return JsonMapper.deserialize<T>(utf8.decode(response.bodyBytes).toString());
    } else {
      throw Exception([
        'Failed Http request status code : ${response?.statusCode}',
        JsonMapper.deserialize<T>(utf8.decode(response!.bodyBytes).toString())
      ]);
    }
  }

  Future<T?> _callApi<T>(String method, String uri, {Map<String, dynamic>? params}) async {
    _addJwtToken();
    uri = _removeFirstSlash(uri);

    http.Response? response;
    if (method == 'get') {
      response = await http.get(
          Uri.parse('$_host/$uri?${Uri(queryParameters: params).query}'),
          headers: _header);
    } else if (method == 'post') {
      response = await http.post(Uri.parse('$_host/$uri'),
          body: json.encode(params), headers: _header);
    } else if (method == 'put') {
      response = await http.put(Uri.parse('$_host/$uri'),
          body: json.encode(params), headers: _header);
    }

    return _result<T>(response);
  }

  Future<T?> get<T>(String uri, {Map<String, dynamic>? params}) {
    return _callApi<T>('get', uri, params: params);
  }

  Future<T?> post<T>(String uri, {Map<String, dynamic>? params}) {
    return _callApi<T>('post', uri, params: params);
  }

  Future<T?> put<T>(String uri, {Map<String, dynamic>? params}) {
    return _callApi<T>('put', uri, params: params);
  }
}
