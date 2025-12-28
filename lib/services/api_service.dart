import 'dart:convert';
import 'dart:io';
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
    return ApiResponse<T>(
      success: json['success'] ?? true,
      message: json['message'] ?? '',
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
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint').replace(
      queryParameters: queryParams?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );

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
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

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
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

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
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

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
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);

    // Add headers - include both X-User-ID and Authorization Bearer token
    request.headers.addAll({
      if (_userId != null) 'X-User-ID': _userId!,
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    });

    // Add files
    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );
    }

    try {
      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
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
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);

    // Add headers - include both X-User-ID and Authorization Bearer token
    request.headers.addAll({
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
      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    // Decode response body as UTF-8 to properly handle Vietnamese characters
    final bodyString = utf8.decode(response.bodyBytes);
    final body = bodyString.isNotEmpty ? jsonDecode(bodyString) : null;

    // Removed debug-only checks

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: body?['detail'] ?? body?['message'] ?? 'Unknown error',
      body: body,
    );
  }

  void dispose() {
    _client.close();
  }
}
