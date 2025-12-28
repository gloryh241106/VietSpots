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
        // Mirror session into AuthService so its updateUser() can authenticate
        _authService.setSession(_session!);
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
          // Mirror session into AuthService so its updateUser() can authenticate
          _authService.setSession(_session!);
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
    String? introduction,
  }) async {
    if (_user == null) return false;

    try {
      // Saving to Supabase requires a valid session token. Refresh it first
      // to ensure the JWT is not expired.
      if (_session != null) {
        final refreshResp = await _authService.refreshSession();
        if (refreshResp.success && refreshResp.session != null) {
          _session = refreshResp.session;
          _authService.setSession(_session!);
        } else {
          _errorMessage = 'Không thể làm mới phiên. Vui lòng đăng nhập lại.';
          notifyListeners();
          return false;
        }
      } else {
        // No Supabase session — cannot persist to Supabase. Inform caller.
        _errorMessage = 'Không có phiên Supabase. Vui lòng đăng nhập.';
        notifyListeners();
        return false;
      }

      // Prefer saving to Supabase when logged in there. Put all profile fields
      // into user metadata for Supabase Auth so they persist with the user.
      // Note: Do NOT send phone to the phone parameter of updateUser() because
      // Supabase Auth attempts SMS verification on phone changes, which fails
      // if SMS provider is not configured. Instead, store phone as metadata only.

      if (_session != null) {
        final metadata = <String, dynamic>{
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
          if (phone != null) 'phone': phone,
          if (introduction != null) 'introduction': introduction,
        };

        final authResp = await _authService.updateUser(
          email: email,
          phone: null,
          displayName: name,
          avatarUrl: avatarUrl,
          metadata: metadata.isNotEmpty ? metadata : null,
        );

        if (!authResp.success) {
          _errorMessage = authResp.message ?? 'Failed to update Supabase user';
          notifyListeners();
          return false;
        }
      } else {
        // No Supabase session — cannot persist to Supabase. Inform caller.
        _errorMessage = 'Không có phiên Supabase. Vui lòng đăng nhập.';
        notifyListeners();
        return false;
      }

      // Also persist into the public `users` table so the database row is updated
      // (the app's UI and backend often read from this table).
      try {
        // Normalize gender to match DB check constraint: 'male'|'female'|'other'
        String? normalizedGender;
        if (gender != null) {
          final g = gender.trim().toLowerCase();
          if (['male', 'm', 'nam', 'nam', 'nam'].contains(g) ||
              g.startsWith('nam')) {
            normalizedGender = 'male';
          } else if (['female', 'f', 'nu', 'nữ', 'nư', 'n'].contains(g) ||
              g.startsWith('n')) {
            normalizedGender = 'female';
          } else if (['other', 'khác', 'khac', 'k'].contains(g) ||
              g.startsWith('kh')) {
            normalizedGender = 'other';
          } else {
            normalizedGender = 'other';
          }
        }

        final upsertRecord = <String, dynamic>{
          'id': _user!.id,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (age != null) 'age': age,
          if (normalizedGender != null) 'gender': normalizedGender,
          if (introduction != null) 'introduction': introduction,
        };

        final dbResp = await _authService.upsertUserRecord(upsertRecord);
        if (!dbResp.success) {
          _errorMessage = dbResp.message ?? 'Không thể lưu vào bảng users';
          notifyListeners();
          return false;
        }
      } catch (e) {
        _errorMessage = 'Lỗi lưu DB: ${e.toString()}';
        notifyListeners();
        return false;
      }

      // Update local state
      _user = _user!.copyWith(
        name: name,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        age: age,
        gender: gender,
        introduction: introduction,
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
    if (_user == null) return;

    // Local update immediately for responsive UI
    _user = _user!.copyWith(
      religion: religion,
      culture: culture,
      hobby: hobby,
      preferences: preferences,
      companionType: companionType,
    );
    notifyListeners();

    // Persist to Supabase (Auth metadata + public.users table) in background
    () async {
      try {
        // Map UI values (English) to DB-allowed Vietnamese codes used in CHECKs
        final Map<String, String> cultureMap = {
          'Vietnamese': 'Việt Nam',
          'Chinese': 'Trung Quốc',
          'Japanese': 'Nhật Bản',
          'Korean': 'Hàn Quốc',
          'Thai': 'Thái Lan',
          'Indian': 'Ấn Độ',
          'Western / European': 'Phương Tây / Châu Âu',
          'American': 'Mỹ',
          'Middle Eastern': 'Trung Đông',
          'African': 'Châu Phi',
          'Other': 'Khác',
        };

        final Map<String, String> religionMap = {
          'None': 'Không',
          'Buddhism': 'Phật giáo',
          'Christianity': 'Thiên Chúa giáo',
          'Islam': 'Hồi giáo',
          'Hinduism': 'Ấn Độ giáo',
          'Judaism': 'Do Thái giáo',
          'Sikhism': 'Đạo Sikh',
          'Other': 'Khác',
        };

        final Map<String, String> companionMap = {
          'Solo': 'Một mình',
          'Couple': 'Cặp đôi',
          'Family': 'Gia đình',
          'Friends': 'Bạn bè',
        };

        final Map<String, String> hobbyMap = {
          'Adventure': 'Phiêu lưu',
          'Less travelling': 'Ít di chuyển',
          'Beautiful': 'Đẹp',
          'Mysterious': 'Bí ẩn',
          'Food': 'Ẩm thực',
          'Culture': 'Văn hóa',
          'Nature': 'Thiên nhiên',
          'Nightlife': 'Cuộc sống về đêm',
        };

        // Build DB values
        final String? dbCulture = culture != null
            ? cultureMap[culture] ?? culture
            : null;
        final String? dbReligion = religion != null
            ? religionMap[religion] ?? religion
            : null;
        final String? dbCompanion = companionType != null
            ? companionMap[companionType] ?? companionType
            : null;

        List<String>? dbHobby;
        if (preferences != null && preferences.isNotEmpty) {
          dbHobby = preferences.map((p) => hobbyMap[p] ?? p).toList();
        } else if (hobby != null && hobby.isNotEmpty) {
          dbHobby = [hobbyMap[hobby] ?? hobby];
        }

        // Ensure we have a Supabase session
        if (_session == null) {
          _errorMessage = 'Không có phiên Supabase. Vui lòng đăng nhập.';
          notifyListeners();
          return;
        }

        final refreshResp = await _authService.refreshSession();
        if (!(refreshResp.success && refreshResp.session != null)) {
          _errorMessage = 'Không thể làm mới phiên. Vui lòng đăng nhập lại.';
          notifyListeners();
          return;
        }
        _session = refreshResp.session;
        _authService.setSession(_session!);

        // Update Supabase Auth metadata (for profile sync)
        final metadata = <String, dynamic>{
          if (dbHobby != null) 'hobby': dbHobby,
          if (dbCulture != null) 'culture': dbCulture,
          if (dbReligion != null) 'religion': dbReligion,
          if (dbCompanion != null) 'companion_type': dbCompanion,
        };

        if (metadata.isNotEmpty) {
          final authResp = await _authService.updateUser(metadata: metadata);
          if (!authResp.success) {
            _errorMessage =
                authResp.message ?? 'Không thể cập nhật metadata Auth';
            notifyListeners();
            return;
          }
        }

        // Upsert into public.users table
        final upsertRecord = <String, dynamic>{
          'id': _user!.id,
          if (dbCulture != null) 'culture': dbCulture,
          if (dbReligion != null) 'religion': dbReligion,
          if (dbCompanion != null) 'companion_type': dbCompanion,
          if (dbHobby != null) 'hobby': dbHobby,
        };

        if (upsertRecord.keys.length > 1) {
          final dbResp = await _authService.upsertUserRecord(upsertRecord);
          if (!dbResp.success) {
            _errorMessage =
                dbResp.message ?? 'Không thể lưu thông tin riêng tư vào DB';
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        _errorMessage = 'Lỗi lưu thông tin riêng tư: ${e.toString()}';
        notifyListeners();
      }
    }();

    return;
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
    // Also clear session stored inside AuthService
    _authService.clearSession();
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
