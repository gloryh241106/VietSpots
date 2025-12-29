import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
// dart:typed_data not required; `package:flutter/foundation.dart` provides needed types
// removed unused import

/// Base API configuration
class ApiConfig {
  static const String baseUrl =
      'https://vietspotbackend-production.up.railway.app/api';
  static const Duration timeout = Duration(seconds: 30);
}

/// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    final dynamic rawMessage = json['message'];
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: rawMessage is String
          ? rawMessage
          : (rawMessage == null ? '' : rawMessage.toString()),
      data: fromJsonT != null && json['data'] != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }
}

/// HTTP Exception with details
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;

  ApiException({required this.statusCode, required this.message, this.body});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Main API Service - handles all HTTP requests
class ApiService {
  final http.Client _client;
  String? _userId;
  String? _accessToken;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    String base = ApiConfig.baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    String ep = endpoint;
    if (!ep.startsWith('/')) ep = '/$ep';
    final uri = Uri.parse('$base$ep');
    if (queryParams == null) return uri;
    return uri.replace(
      queryParameters: queryParams.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  /// Set user ID for authenticated requests
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Expose the current user id (if set) for other services to use
  String? get userId => _userId;

  /// Set access token for Supabase authentication
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Common headers
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_userId != null) 'X-User-ID': _userId!,
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  /// GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);

    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(ApiConfig.timeout);

      // Proceed to handle response normally

      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(endpoint);

    try {
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout ?? ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// PUT request
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = _buildUri(endpoint);

    try {
      final response = await _client
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint) async {
    final uri = _buildUri(endpoint);

    try {
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// Upload files (multipart)
  Future<dynamic> uploadFiles(
    String endpoint,
    List<File> files, {
    String fieldName = 'files',
  }) async {
    final uri = _buildUri(endpoint);
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Accept': 'application/json',
      if (_userId != null) 'X-User-ID': _userId!,
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    });

    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );
    }

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// Upload files from bytes (works on Web)
  Future<dynamic> uploadFilesBytes(
    String endpoint,
    List<Uint8List> filesBytes,
    List<String> filenames, {
    String fieldName = 'files',
  }) async {
    final uri = _buildUri(endpoint);
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Accept': 'application/json',
      if (_userId != null) 'X-User-ID': _userId!,
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    });

    for (int i = 0; i < filesBytes.length; i++) {
      final name = i < filenames.length ? filenames[i] : 'file_$i.jpg';
      final mimeType = lookupMimeType(name) ?? 'application/octet-stream';
      MediaType? mediaType;
      try {
        final parts = mimeType.split('/');
        mediaType = MediaType(parts[0], parts[1]);
      } catch (_) {
        mediaType = MediaType('application', 'octet-stream');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          filesBytes[i],
          filename: name,
          contentType: mediaType,
        ),
      );
    }

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// POST request that returns raw bytes (useful for binary responses like MP3)
  Future<Uint8List> postBinary(
    String endpoint, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(endpoint);

    try {
      // Do not set Content-Type to application/json to allow binary responses
      final response = await _client
          .post(
            uri,
            headers: {
              if (_userId != null) 'X-User-ID': _userId!,
              if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
            },
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? ApiConfig.timeout);

      // If non-2xx, try to decode error as JSON/text for message
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final bodyString = utf8.decode(response.bodyBytes);
        dynamic parsed;
        try {
          parsed = jsonDecode(bodyString);
        } catch (_) {
          parsed = bodyString;
        }

        final dynamic extractedMessage = parsed is Map
            ? (parsed['message'] ?? parsed['detail'] ?? parsed)
            : parsed;
        final String message = extractedMessage is String
            ? extractedMessage
            : extractedMessage.toString();

        throw ApiException(
          statusCode: response.statusCode,
          message: message,
          body: parsed,
        );
      }

      return response.bodyBytes;
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    // Decode response body as UTF-8 to properly handle Vietnamese characters
    final bodyString = utf8.decode(response.bodyBytes);
    dynamic body;
    if (bodyString.isNotEmpty) {
      try {
        body = jsonDecode(bodyString);
      } catch (e) {
        body = bodyString;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'Unknown error';
    if (body is Map<String, dynamic>) {
      final dynamic msgValue = body['detail'] ?? body['message'] ?? message;
      message = msgValue is String ? msgValue : msgValue.toString();
    } else if (body is String && body.isNotEmpty) {
      message = body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      body: body,
    );
  }

  void dispose() {
    _client.close();
  }
}
