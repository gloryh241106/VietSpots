import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Compile-time fallbacks when building with `--dart-define`.
const String _kSupabaseUrlDefine = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);
const String _kSupabaseAnonKeyDefine = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

/// Supabase Auth configuration
/// Bạn cần lấy các giá trị này từ Supabase project của bạn
class SupabaseConfig {
  /// Supabase project URL
  static String get supabaseUrl {
    try {
      final v = dotenv.env['SUPABASE_URL'];
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}

    if (_kSupabaseUrlDefine.isNotEmpty) return _kSupabaseUrlDefine;
    return '';
  }

  /// Supabase anon/public key
  static String get supabaseAnonKey {
    try {
      final v = dotenv.env['SUPABASE_ANON_KEY'];
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}

    if (_kSupabaseAnonKeyDefine.isNotEmpty) return _kSupabaseAnonKeyDefine;
    return '';
  }

  /// Auth endpoints
  static String get authUrl => '$supabaseUrl/auth/v1';
}

/// User model from Supabase Auth
class AuthUser {
  final String id;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  AuthUser({
    required this.id,
    this.email,
    this.phone,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
    this.lastSignInAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final metadata = json['user_metadata'] ?? {};
    return AuthUser(
      id: json['id'] ?? '',
      email: json['email'],
      phone: json['phone'],
      displayName: metadata['display_name'] ?? metadata['full_name'],
      avatarUrl: metadata['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.tryParse(json['last_sign_in_at'])
          : null,
    );
  }
}

/// Auth session with tokens
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final AuthUser user;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
      tokenType: json['token_type'] ?? 'bearer',
      user: AuthUser.fromJson(json['user'] ?? {}),
    );
  }

  bool get isExpired {
    // Add buffer of 60 seconds
    return expiresIn <= 60;
  }
}

/// Auth response wrapper
class AuthResponse {
  final bool success;
  final String? message;
  final AuthSession? session;
  final AuthUser? user;

  AuthResponse({required this.success, this.message, this.session, this.user});
}

/// Auth exception
class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  @override
  String toString() => 'AuthException($code): $message';
}

/// Authentication Service using Supabase Auth
class AuthService {
  final http.Client _client;
  AuthSession? _currentSession;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Get current session
  AuthSession? get currentSession => _currentSession;

  /// Get current user
  AuthUser? get currentUser => _currentSession?.user;

  /// Check if user is logged in
  bool get isLoggedIn => _currentSession != null;

  /// Common auth headers
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'apikey': SupabaseConfig.supabaseAnonKey,
  };

  /// Headers with auth token
  Map<String, String> get _authHeaders => {
    ..._headers,
    if (_currentSession != null)
      'Authorization': 'Bearer ${_currentSession!.accessToken}',
  };

  // ========================
  // SIGN UP
  // ========================

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/signup'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {
            if (displayName != null) 'display_name': displayName,
            ...?metadata,
          },
        }),
      );

      return _handleAuthResponse(response);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Sign up with phone number
  Future<AuthResponse> signUpWithPhone({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/signup'),
        headers: _headers,
        body: jsonEncode({
          'phone': phone,
          'password': password,
          'data': {if (displayName != null) 'display_name': displayName},
        }),
      );

      return _handleAuthResponse(response);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  // ========================
  // SIGN IN
  // ========================

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/token?grant_type=password'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      final authResponse = _handleAuthResponse(response);
      if (authResponse.success && authResponse.session != null) {
        _currentSession = authResponse.session;
      }
      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Sign in with phone and password
  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/token?grant_type=password'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'password': password}),
      );

      final authResponse = _handleAuthResponse(response);
      if (authResponse.success && authResponse.session != null) {
        _currentSession = authResponse.session;
      }
      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Sign in with OTP (magic link) - sends OTP to email
  Future<AuthResponse> signInWithOtp({String? email, String? phone}) async {
    assert(email != null || phone != null, 'Email or phone is required');

    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/otp'),
        headers: _headers,
        body: jsonEncode({
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthResponse(success: true, message: 'OTP đã được gửi');
      }

      final body = jsonDecode(response.body);
      return AuthResponse(
        success: false,
        message: body['error_description'] ?? body['msg'] ?? 'Lỗi gửi OTP',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Verify OTP code
  Future<AuthResponse> verifyOtp({
    required String token,
    String? email,
    String? phone,
    String type = 'sms', // 'sms' or 'email'
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/verify'),
        headers: _headers,
        body: jsonEncode({
          'token': token,
          'type': type,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        }),
      );

      final authResponse = _handleAuthResponse(response);
      if (authResponse.success && authResponse.session != null) {
        _currentSession = authResponse.session;
      }
      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  // ========================
  // PASSWORD RESET
  // ========================

  /// Request password reset
  Future<AuthResponse> resetPasswordForEmail(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/recover'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthResponse(
          success: true,
          message: 'Email đặt lại mật khẩu đã được gửi',
        );
      }

      final body = jsonDecode(response.body);
      return AuthResponse(
        success: false,
        message: body['error_description'] ?? body['msg'] ?? 'Lỗi gửi email',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Update password (when logged in)
  Future<AuthResponse> updatePassword(String newPassword) async {
    if (_currentSession == null) {
      return AuthResponse(success: false, message: 'Chưa đăng nhập');
    }

    try {
      final response = await _client.put(
        Uri.parse('${SupabaseConfig.authUrl}/user'),
        headers: _authHeaders,
        body: jsonEncode({'password': newPassword}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthResponse(success: true, message: 'Đã cập nhật mật khẩu');
      }

      final body = jsonDecode(response.body);
      return AuthResponse(
        success: false,
        message: body['error_description'] ?? body['msg'] ?? 'Lỗi cập nhật',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  // ========================
  // USER PROFILE
  // ========================

  /// Get current user profile
  Future<AuthResponse> getUser() async {
    if (_currentSession == null) {
      return AuthResponse(success: false, message: 'Chưa đăng nhập');
    }

    try {
      final response = await _client.get(
        Uri.parse('${SupabaseConfig.authUrl}/user'),
        headers: _authHeaders,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        return AuthResponse(success: true, user: AuthUser.fromJson(body));
      }

      return AuthResponse(success: false, message: 'Lỗi lấy thông tin user');
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Update user profile
  Future<AuthResponse> updateUser({
    String? email,
    String? phone,
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentSession == null) {
      return AuthResponse(success: false, message: 'Chưa đăng nhập');
    }

    try {
      final response = await _client.put(
        Uri.parse('${SupabaseConfig.authUrl}/user'),
        headers: _authHeaders,
        body: jsonEncode({
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          'data': {
            if (displayName != null) 'display_name': displayName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            ...?metadata,
          },
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        return AuthResponse(success: true, user: AuthUser.fromJson(body));
      }

      final body = jsonDecode(response.body);
      return AuthResponse(
        success: false,
        message: body['error_description'] ?? body['msg'] ?? 'Lỗi cập nhật',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Upsert into Postgres `users` table via Supabase REST API.
  /// Uses authenticated user token so RLS policies can apply.
  Future<AuthResponse> upsertUserRecord(Map<String, dynamic> record) async {
    if (_currentSession == null) {
      return AuthResponse(success: false, message: 'Chưa đăng nhập');
    }

    try {
      final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/users');
      final resp = await _client.post(
        uri,
        headers: {
          ..._authHeaders,
          // Allow upsert (merge duplicates) behavior
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode(record),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return AuthResponse(success: true);
      }

      final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
      return AuthResponse(
        success: false,
        message: body != null && body['message'] != null
            ? body['message']
            : 'Lỗi upsert user',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  // ========================
  // SESSION MANAGEMENT
  // ========================

  /// Refresh session token
  Future<AuthResponse> refreshSession() async {
    if (_currentSession == null) {
      return AuthResponse(success: false, message: 'Chưa đăng nhập');
    }

    try {
      final response = await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/token?grant_type=refresh_token'),
        headers: _headers,
        body: jsonEncode({'refresh_token': _currentSession!.refreshToken}),
      );

      final authResponse = _handleAuthResponse(response);
      if (authResponse.success && authResponse.session != null) {
        _currentSession = authResponse.session;
      }
      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  /// Sign out
  Future<AuthResponse> signOut() async {
    if (_currentSession == null) {
      return AuthResponse(success: true, message: 'Đã đăng xuất');
    }

    try {
      await _client.post(
        Uri.parse('${SupabaseConfig.authUrl}/logout'),
        headers: _authHeaders,
      );
    } catch (_) {
      // Ignore errors on logout
    }

    _currentSession = null;
    return AuthResponse(success: true, message: 'Đã đăng xuất');
  }

  /// Set session from stored tokens (e.g., from SharedPreferences)
  void setSession(AuthSession session) {
    _currentSession = session;
  }

  /// Clear current session
  void clearSession() {
    _currentSession = null;
  }

  // ========================
  // HELPERS
  // ========================

  AuthResponse _handleAuthResponse(http.Response response) {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Check if response contains session
      if (body.containsKey('access_token')) {
        return AuthResponse(success: true, session: AuthSession.fromJson(body));
      }

      // Check if response contains user only (e.g., after signup with email confirmation)
      if (body.containsKey('id')) {
        return AuthResponse(
          success: true,
          user: AuthUser.fromJson(body),
          message: 'Vui lòng kiểm tra email để xác nhận tài khoản',
        );
      }

      return AuthResponse(success: true);
    }

    // Error response
    final errorMessage =
        body['error_description'] ??
        body['msg'] ??
        body['message'] ??
        'Đã xảy ra lỗi';

    return AuthResponse(success: false, message: errorMessage);
  }

  void dispose() {
    _client.close();
  }
}
