import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Base API configuration
class ApiConfig {
  static const String baseUrl =
      'http://127.0.0.1:8000/api';
      //'https://vietspotbackend-production.up.railway.app/api';
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

  /// Set access token for authenticated requests
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

    // Add headers
    request.headers.addAll({if (_userId != null) 'X-User-ID': _userId!});

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

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    // Decode response body as UTF-8 to properly handle Vietnamese characters
    final bodyString = utf8.decode(response.bodyBytes);
    final body = bodyString.isNotEmpty ? jsonDecode(bodyString) : null;

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
