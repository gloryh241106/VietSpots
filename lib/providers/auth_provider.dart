import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vietspots/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoggedIn = false;

  UserModel? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  final _supabase = Supabase.instance.client;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _syncUserFromSupabase(session.user);
      } else {
        _user = null;
        _isLoggedIn = false;
        notifyListeners();
      }
    });

    // Check current session
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _syncUserFromSupabase(session.user);
    }
  }

  void _syncUserFromSupabase(User supabaseUser) {
    _user = UserModel(
      id: supabaseUser.id,
      name:
          supabaseUser.userMetadata?['name'] ??
          supabaseUser.email?.split('@')[0] ??
          'User',
      email: supabaseUser.email ?? '',
      avatarUrl: supabaseUser.userMetadata?['avatar_url'],
      religion: supabaseUser.userMetadata?['religion'],
      companionType: supabaseUser.userMetadata?['companion_type'],
    );
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      // User will be synced via auth state listener
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(String email, String password, {String? name}) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name ?? email.split('@')[0],
          'avatar_url': 'https://i.pravatar.cc/300',
        },
      );
      // User will be synced via auth state listener
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    if (_user != null) {
      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'name': name ?? _user!.name,
              'avatar_url': avatarUrl ?? _user!.avatarUrl,
            },
          ),
        );
        _user = _user!.copyWith(name: name, avatarUrl: avatarUrl);
        notifyListeners();
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<void> updateSurvey({String? religion, String? companionType}) async {
    if (_user != null) {
      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'religion': religion ?? _user!.religion,
              'companion_type': companionType ?? _user!.companionType,
            },
          ),
        );
        _user = _user!.copyWith(
          religion: religion,
          companionType: companionType,
        );
        notifyListeners();
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<void> completeOnboarding() async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'has_onboarded': true}),
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      // User will be cleared via auth state listener
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
}
