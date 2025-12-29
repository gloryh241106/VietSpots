import 'dart:io';
import 'dart:convert';
// dart:typed_data not required; `package:flutter/foundation.dart` provides Uint8List
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'comment_service.dart';
import 'ocr_stub.dart';

/// Image upload response
class ImageUploadResponse {
  final bool success;
  final String message;
  final List<String> urls;

  ImageUploadResponse({
    required this.success,
    required this.message,
    required this.urls,
  });

  factory ImageUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageUploadResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      urls: (json['urls'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Service for Images API
class ImageService {
  final ApiService _api;

  ImageService(this._api);

  /// GET /comments/{comment_id}/images - Get comment images
  Future<List<ImageDTO>> getCommentImages(String commentId) async {
    final response = await _api.get('/comments/$commentId/images');
    return (response as List).map((e) => ImageDTO.fromJson(e)).toList();
  }

  /// GET /places/{place_id}/images - Get place images
  Future<List<ImageDTO>> getPlaceImages(String placeId) async {
    final response = await _api.get('/places/$placeId/images');
    return (response as List).map((e) => ImageDTO.fromJson(e)).toList();
  }

  /// POST /api/upload - Upload images
  /// POST /upload - Upload images (ApiConfig.baseUrl already contains /api prefix)
  Future<ImageUploadResponse> uploadImages(List<File> files) async {
    final response = await _api.uploadFiles('/upload', files);
    return ImageUploadResponse.fromJson(response);
  }

  /// Upload images from bytes (for Web)
  Future<ImageUploadResponse> uploadImagesFromBytes(
    List<Uint8List> filesBytes,
    List<String> filenames,
  ) async {
    final response = await _api.uploadFilesBytes(
      '/upload',
      filesBytes,
      filenames,
    );
    return ImageUploadResponse.fromJson(response);
  }

  /// Extract text from an image (bytes) using optional backend OCR endpoint.
  /// Returns the recognized text or empty string on failure.
  Future<String> extractTextFromBytes(Uint8List bytes) async {
    try {
      final b64 = base64Encode(bytes);
      final resp = await _api.post('/ocr', body: {'image_base64': b64});
      if (resp is Map<String, dynamic> && resp['text'] != null) {
        return resp['text'].toString();
      }
    } catch (e) {
      debugPrint('OCR request failed: $e');
    }

    // Fallback to local OCR stub (no-op) so feature degrades gracefully.
    try {
      // Avoid circular import in some setups by importing lazily.
      // This keeps the stub optional and easy to replace.
      final stub = await _loadOcrStub(bytes);
      return stub;
    } catch (e) {
      debugPrint('OCR stub failed: $e');
    }

    return '';
  }

  Future<String> _loadOcrStub(Uint8List bytes) async {
    // Lazy import of the stub implementation
    try {
      // Use a direct import (the file is in the package)
      return await mockOcrFromBytes(bytes);
    } catch (e) {
      debugPrint('Could not run OCR stub: $e');
      return '';
    }
  }

  /// Very small heuristic language detector based on character ranges.
  /// Returns a language tag suitable for STT endpoints, e.g. 'vi-VN' or 'en-US'.
  String detectLanguageFromText(String text) {
    if (text.isEmpty) return 'en-US';
    // Vietnamese characters
    final viPattern = RegExp(r'[ăâđơưàáảãạậầấẩẫắằắ́]');
    if (viPattern.hasMatch(text)) return 'vi-VN';
    // CJK
    final cjk = RegExp(r'[\u4E00-\u9FFF]');
    if (cjk.hasMatch(text)) return 'zh-CN';
    // Cyrillic
    final ru = RegExp(r'[\u0400-\u04FF]');
    if (ru.hasMatch(text)) return 'ru-RU';
    // Arabic
    final ar = RegExp(r'[\u0600-\u06FF]');
    if (ar.hasMatch(text)) return 'ar-SA';
    // Hindi (Devanagari)
    final hi = RegExp(r'[\u0900-\u097F]');
    if (hi.hasMatch(text)) return 'hi-IN';
    // Fallback: if looks Latin but contains accents, choose 'es' or 'fr' is hard;
    // default to English
    return 'en-US';
  }
}
