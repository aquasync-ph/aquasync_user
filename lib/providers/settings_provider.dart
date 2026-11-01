import 'package:flutter/material.dart';
import '../models/app_language.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  AppLanguage _language = AppLanguage.english;

  bool get isDarkMode => _isDarkMode;
  bool get pushNotifications => _pushNotifications;
  bool get soundEnabled => _soundEnabled;
  AppLanguage get language => _language;

  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setLanguage(AppLanguage lang) {
    _language = lang;
    notifyListeners();
  }

  void togglePushNotifications(bool value) {
    _pushNotifications = value;
    notifyListeners();
  }

  void toggleSound(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }
}
