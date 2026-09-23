import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

FileService fileService = FileService();
class FileService {
  static final FileService _instance = FileService._privateConstructor();
  late ImagePicker _picker;

  factory FileService(){
    return _instance;
  }

  FileService._privateConstructor(){
    _picker = ImagePicker();
  }

  Future<ImagePickerResponse> openImagePicker(String type, Map<String, dynamic>? options) async {
    var response = ImagePickerResponse();
    response.code = "success";
    try {
      if (type == 'gallery') {
        response.files = await _pickMultiImage(options: options);
      } else if (type == 'camera') {
        response.files = await _pickCameraImage(options: options);
      }
    } on PlatformException catch (e) {
      response.code = e.code;
    } catch (e) {
      response.code = "fail";
    }
    return response;
  }

  Future<List<String>> _pickMultiImage({Map<String, dynamic>? options}) async {
    final List<XFile> pickedFileList = await _picker.pickMultiImage(
      maxWidth: options?['maxWidth'],
      maxHeight: options?['maxHeight'],
      imageQuality: options?['imageQuality'],
    );
    List<String> result = [];
    for (var file in pickedFileList) {
      String base64 = await _xFileToBase64(file);
      result.add(base64);
    }
    return result;
  }

  Future<List<String>> _pickCameraImage({Map<String, dynamic>? options}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: options?['maxWidth'],
      maxHeight: options?['maxHeight'],
      imageQuality: options?['imageQuality'],
    );

    List<String> result = [];
    if(pickedFile != null) {
      String base64 = await _xFileToBase64(pickedFile);
      result.add(base64);
    }
    return result;
  }

   Future<String> _xFileToBase64(XFile? file) async {
    if(file == null) return "";
    List<int> bytes = await file.readAsBytes();
    String base64String = base64.encode(bytes);
    return base64String;
  }
}


class ImagePickerResponse {
  late String code;
  late List<String> files = [];

  Map<String, dynamic> toJson() {
    return {
      "code": code,
      "files": files,
    };

  }
}