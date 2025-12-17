import 'package:flutter/material.dart';
import 'package:vietspots/models/user_model.dart';
import 'package:vietspots/services/auth_service.dart';
import 'package:vietspots/services/api_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService;

  UserModel? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  AuthSession? _session;

  AuthProvider(this._apiService);

  UserModel? get user => _user;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _session;
  String? get userId => _session?.user.id;

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    // Validate input
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Vui lòng nhập email và mật khẩu';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.success && response.session != null) {
        _session = response.session;
        // Set user ID and access token in API service for authenticated requests
        _apiService.setUserId(response.session!.user.id);
        _apiService.setAccessToken(response.session!.accessToken);
        _user = UserModel(
          id: response.session!.user.id,
          name: response.session!.user.displayName ?? 'User',
          email: response.session!.user.email ?? email,
          avatarUrl: response.session!.user.avatarUrl,
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Đăng nhập thất bại';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối: ${e.toString()}';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Register with email and password
  Future<bool> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    // Validate input
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Vui lòng nhập email và mật khẩu';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (response.success) {
        if (response.session != null) {
          // Auto login after registration
          _session = response.session;
          // Set user ID and access token in API service for authenticated requests
          _apiService.setUserId(response.session!.user.id);
          _apiService.setAccessToken(response.session!.accessToken);
          _user = UserModel(
            id: response.session!.user.id,
            name: response.session!.user.displayName ?? displayName ?? 'User',
            email: response.session!.user.email ?? email,
            avatarUrl: response.session!.user.avatarUrl,
          );
          _status = AuthStatus.authenticated;
        } else {
          // Need email confirmation
          _errorMessage =
              response.message ??
              'Vui lòng kiểm tra email để xác nhận tài khoản';
          _status = AuthStatus.unauthenticated;
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Đăng ký thất bại';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối: ${e.toString()}';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    if (email.isEmpty) {
      _errorMessage = 'Vui lòng nhập email';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final response = await _authService.resetPasswordForEmail(email);
      _errorMessage = response.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return response.success;
    } catch (e) {
      _errorMessage = 'Lỗi: ${e.toString()}';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    int? age,
    String? gender,
  }) async {
    if (_user == null) return false;

    try {
      // Update on server if logged in with Supabase
      if (_session != null) {
        await _authService.updateUser(displayName: name, avatarUrl: avatarUrl);
      }

      // Update local state
      _user = _user!.copyWith(
        name: name,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        age: age,
        gender: gender,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Update password
  Future<bool> updatePassword(String newPassword) async {
    if (_session == null) {
      _errorMessage = 'Chưa đăng nhập';
      return false;
    }

    try {
      final response = await _authService.updatePassword(newPassword);
      _errorMessage = response.message;
      notifyListeners();
      return response.success;
    } catch (e) {
      _errorMessage = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Verify password (for demo - in real app, use server-side verification)
  bool verifyPassword(String password) {
    // In a real app, this should be handled server-side
    return true;
  }

  void updateSurvey({
    String? religion,
    String? culture,
    String? hobby,
    List<String>? preferences,
    String? companionType,
  }) {
    if (_user != null) {
      _user = _user!.copyWith(
        religion: religion,
        culture: culture,
        hobby: hobby,
        preferences: preferences,
        companionType: companionType,
      );
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authService.signOut();
    // Clear user ID and access token from API service
    _apiService.setUserId(null);
    _apiService.setAccessToken(null);
    _user = null;
    _session = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
