import 'package:flutter/material.dart';
import 'package:vietspots/models/user_model.dart';
import 'package:vietspots/utils/mock_data.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoggedIn = false;

  UserModel? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  void login(String email, String password) {
    // Simulate API call
    _user = MockDataService.currentUser;
    _isLoggedIn = true;
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
    notifyListeners();
  }

  void updateProfile({String? name, String? avatarUrl}) {
    if (_user != null) {
      _user = _user!.copyWith(name: name, avatarUrl: avatarUrl);
      notifyListeners();
    }
  }

  void updateSurvey({String? religion, String? companionType}) {
    if (_user != null) {
      _user = _user!.copyWith(religion: religion, companionType: companionType);
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
