import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyUseDynamicColor = 'use_dynamic_color';
  static const String _keyIsAmoled = 'is_amoled';
  static const String _keyLocale = 'locale';

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = true;
  bool _isAmoled = false;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  bool get isAmoled => _isAmoled;
  Locale? get locale => _locale;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final modeIndex = prefs.getInt(_keyThemeMode);
    if (modeIndex != null) {
      _themeMode = ThemeMode.values[modeIndex];
    }

    _useDynamicColor = prefs.getBool(_keyUseDynamicColor) ?? true;
    _isAmoled = prefs.getBool(_keyIsAmoled) ?? false;

    final localeCode = prefs.getString(_keyLocale);
    if (localeCode != null) {
      _locale = Locale(localeCode);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setUseDynamicColor(bool value) async {
    if (_useDynamicColor == value) return;
    _useDynamicColor = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDynamicColor, value);
  }

  Future<void> setIsAmoled(bool value) async {
    if (_isAmoled == value) return;
    _isAmoled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsAmoled, value);
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_keyLocale);
    } else {
      await prefs.setString(_keyLocale, locale.languageCode);
    }
  }
}
