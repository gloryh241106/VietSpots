import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import '../models/place_model.dart';

/// Comment API DTO
class CommentDTO {
  final String id;
  final String placeId;
  final String? userId;
  final String? author;
  final double? rating;
  final String? text;
  final String? date;
  final List<ImageDTO> images;

  CommentDTO({
    required this.id,
    required this.placeId,
    this.userId,
    this.author,
    this.rating,
    this.text,
    this.date,
    this.images = const [],
  });

  factory CommentDTO.fromJson(Map<String, dynamic> json) {
    return CommentDTO(
      id: json['id'] ?? '',
      placeId: json['place_id'] ?? '',
      userId: json['user_id'],
      // Backend may return 'author' or 'author_name'
      author: json['author'] ?? json['author_name'],
      rating: (json['rating'] as num?)?.toDouble(),
      text: json['text'],
      // Accept various date keys
      date: json['date'] ?? json['created_at'] ?? json['timestamp'],
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => ImageDTO.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// Convert to app's PlaceComment model
  PlaceComment toPlaceComment() {
    return PlaceComment(
      id: id,
      author: author ?? 'Anonymous',
      text: text ?? '',
      rating: (rating ?? 5).toInt(),
      imagePath: images.isNotEmpty ? images.first.url : null,
      timestamp: date != null ? _parseTimestamp(date!) : DateTime.now(),
    );
  }

  // Parse timestamp returned from backend. If the string has no timezone
  // information, assume UTC (common for some DBs) to avoid local-time
  // offset issues that make recent comments appear hours older.
  static DateTime _parseTimestamp(String s) {
    // If contains timezone offset or 'Z', parse directly
    if (s.contains('Z') || s.contains('+') || s.contains('-')) {
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    // Try parse as local first, if that gives a time far in the past,
    // attempt parsing as UTC by appending 'Z'.
    final parsedLocal = DateTime.tryParse(s);
    if (parsedLocal != null) return parsedLocal;

    try {
      return DateTime.parse(
        '$s'
        'Z',
      );
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Image API DTO
class ImageDTO {
  final String id;
  final String url;
  final String? placeId;
  final String? commentId;
  final bool? isScraped;
  final String? uploadedAt;

  ImageDTO({
    required this.id,
    required this.url,
    this.placeId,
    this.commentId,
    this.isScraped,
    this.uploadedAt,
  });

  factory ImageDTO.fromJson(Map<String, dynamic> json) {
    return ImageDTO(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      placeId: json['place_id'],
      commentId: json['comment_id'],
      isScraped: json['is_scraped'],
      uploadedAt: json['uploaded_at'],
    );
  }
}

/// Service for Comments API
class CommentService {
  final ApiService _api;

  CommentService(this._api);

  /// GET /places/{place_id}/comments - Get place comments
  Future<List<CommentDTO>> getPlaceComments(
    String placeId, {
    int limit = 20,
    int offset = 0,
    String orderBy = 'recent',
  }) async {
    final response = await _api.get(
      '/places/$placeId/comments',
      queryParams: {'limit': limit, 'offset': offset, 'order_by': orderBy},
    );

    // Temporary debug logging: request/response snapshot for troubleshooting
    try {
      debugPrint(
        'API GET /places/$placeId/comments?limit=$limit&offset=$offset&order_by=$orderBy',
      );
      debugPrint('Response type: ${response.runtimeType}');
      if (response is List) {
        debugPrint('Comments count: ${response.length}');
        if (response.isNotEmpty) {
          debugPrint('First comment (sample): ${jsonEncode(response.first)}');
        }
      } else {
        debugPrint('Response body: ${jsonEncode(response)}');
      }
    } catch (_) {
      // ignore logging errors
    }

    return (response as List).map((e) => CommentDTO.fromJson(e)).toList();
  }

  /// POST /comments - Create new comment
  Future<ApiResponse> createComment({
    required String placeId,
    String? userId,
    String authorName = 'Khách tham quan',
    int rating = 5,
    String? text,
    List<String> imageUrls = const [],
  }) async {
    // Client-side retry with exponential backoff to mitigate transient
    // database timeouts or brief network issues. Will return a failure
    // ApiResponse if all attempts fail.
    const int maxAttempts = 3;
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final requestBody = {
          'place_id': placeId,
          if (userId != null) 'user_id': userId,
          'author_name': authorName,
          'rating': rating,
          if (text != null) 'text': text,
          'image_urls': imageUrls,
        };

        debugPrint(
          'API POST /comments request (attempt $attempt): ${jsonEncode(requestBody)}',
        );

        final response = await _api.post('/comments', body: requestBody);

        try {
          debugPrint(
            'API POST /comments response (attempt $attempt): ${jsonEncode(response)}',
          );
        } catch (_) {}

        final apiResp = ApiResponse.fromJson(response, null);

        // If the create RPC didn't attach images for some reason, try attaching
        // them via the dedicated endpoint as a fallback.
        try {
          final data = apiResp.data as Map<String, dynamic>?;
          final commentId = data != null
              ? (data['comment_id']?.toString())
              : null;
          final imagesCount = data != null
              ? (data['images_count'] as int?) ?? 0
              : 0;

          if (apiResp.success &&
              commentId != null &&
              imageUrls.isNotEmpty &&
              imagesCount == 0) {
            try {
              debugPrint('Attaching images to comment $commentId');
              final attachResp = await _api.post(
                '/comments/$commentId/images',
                body: {'image_urls': imageUrls},
              );
              debugPrint('Attach images response: ${jsonEncode(attachResp)}');
            } catch (e) {
              debugPrint('Failed to attach images to comment $commentId: $e');
            }
          }
        } catch (_) {}

        return apiResp;
      } catch (e) {
        debugPrint(
          'API POST /comments exception (attempt $attempt): ${e.toString()}',
        );
        // If we've exhausted retries, return a failed ApiResponse
        if (attempt >= maxAttempts) {
          return ApiResponse(success: false, message: e.toString());
        }

        // Wait with exponential backoff before retrying
        final delayMs = 500 * (1 << (attempt - 1)); // 500ms, 1s, 2s
        await Future.delayed(Duration(milliseconds: delayMs));
        continue;
      }
    }
  }

  /// PUT /comments/{comment_id} - Update comment
  Future<ApiResponse> updateComment(
    String commentId, {
    String? authorName,
    int? rating,
    String? text,
  }) async {
    final response = await _api.put(
      '/comments/$commentId',
      body: {
        if (authorName != null) 'author_name': authorName,
        if (rating != null) 'rating': rating,
        if (text != null) 'text': text,
      },
    );

    return ApiResponse.fromJson(response, null);
  }

  /// DELETE /comments/{comment_id} - Delete comment
  Future<ApiResponse> deleteComment(String commentId) async {
    final response = await _api.delete('/comments/$commentId');
    return ApiResponse.fromJson(response, null);
  }

  /// POST /comments/{comment_id}/images - Add images to comment
  Future<ApiResponse> addImagesToComment(
    String commentId,
    List<String> imageUrls,
  ) async {
    final response = await _api.post(
      '/comments/$commentId/images',
      body: {'image_urls': imageUrls},
    );
    return ApiResponse.fromJson(response, null);
  }

  /// DELETE /comments/{comment_id}/images/{image_id} - Delete comment image
  Future<ApiResponse> deleteCommentImage(
    String commentId,
    String imageId,
  ) async {
    final response = await _api.delete('/comments/$commentId/images/$imageId');
    return ApiResponse.fromJson(response, null);
  }
}
