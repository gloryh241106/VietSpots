import 'package:flutter/material.dart';
import 'package:vietspots/models/user_model.dart';
import 'package:vietspots/utils/mock_data.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoggedIn = false;
  String? _password; // Demo-only: no backend/storage in this project.

  UserModel? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  void login(String email, String password) {
    // Simulate API call
    _user = MockDataService.currentUser;
    _isLoggedIn = true;
    _password = password;
    notifyListeners();
  }

  void register(String email, String password) {
    // Simulate API call
    _user = UserModel(
      id: 'new_user',
      name: 'New User',
      email: email,
      avatarUrl: 'https://i.pravatar.cc/300',
    );
    _isLoggedIn = true;
    _password = password;
    notifyListeners();
  }

  // --- Password helpers (in-memory, demo only) ---
  bool verifyPassword(String password) => _password == password;

  void updatePassword(String newPassword) {
    _password = newPassword;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    int? age,
    String? gender,
  }) {
    if (_user != null) {
      _user = _user!.copyWith(
        name: name,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        age: age,
        gender: gender,
      );
      notifyListeners();
    }
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

  void logout() {
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
