import 'package:flutter/material.dart';

class LocalizationProvider with ChangeNotifier {
  Locale _locale = const Locale('en');
  bool _isLoading = false;

  Locale get locale => _locale;
  bool get isLoading => _isLoading;

  final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'home': 'Home',
      'notification': 'Notification',
      'favorites': 'Favorites',
      'settings': 'Settings',
      'search_hint': 'Search places...',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'logout': 'Log Out',
      'logout_confirm': 'Are you sure you want to log out?',
      'cancel': 'Cancel',
      'yes': 'Yes',
    },
    'vi': {
      'home': 'Trang chủ',
      'notification': 'Thông báo',
      'favorites': 'Yêu thích',
      'settings': 'Cài đặt',
      'search_hint': 'Tìm kiếm địa điểm...',
      'dark_mode': 'Chế độ tối',
      'language': 'Ngôn ngữ',
      'logout': 'Đăng xuất',
      'logout_confirm': 'Bạn có chắc chắn muốn đăng xuất?',
      'cancel': 'Hủy',
      'yes': 'Có',
    },
    'ru': {
      'home': 'Главная',
      'notification': 'Уведомления',
      'favorites': 'Избранное',
      'settings': 'Настройки',
      'search_hint': 'Поиск мест...',
      'dark_mode': 'Темный режим',
      'language': 'Язык',
      'logout': 'Выйти',
      'logout_confirm': 'Вы уверены, что хотите выйти?',
      'cancel': 'Отмена',
      'yes': 'Да',
    },
    'zh': {
      'home': '首页',
      'notification': '通知',
      'favorites': '收藏',
      'settings': '设置',
      'search_hint': '搜索地点...',
      'dark_mode': '深色模式',
      'language': '语言',
      'logout': '登出',
      'logout_confirm': '您确定要登出吗？',
      'cancel': '取消',
      'yes': '是',
    },
  };

  String translate(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? key;
  }

  Future<void> setLanguage(String languageCode) async {
    _isLoading = true;
    notifyListeners();

    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 3));

    _locale = Locale(languageCode);
    _isLoading = false;
    notifyListeners();
  }
}
