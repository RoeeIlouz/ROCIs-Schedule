import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyUseDynamicColor = 'use_dynamic_color';
  static const String _keyIsAmoled = 'is_amoled';
  static const String _keyUseGlassmorphism = 'use_glassmorphism';
  static const String _keyLocale = 'locale';
  static const String _keyUse24HourFormat = 'use_24_hour_format';
  static const String _keyEnableReminders = 'enable_reminders';

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = true;
  bool _isAmoled = false;
  bool _useGlassmorphism = true;
  Locale? _locale;
  bool _use24HourFormat = true;
  bool _enableReminders = true;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  bool get isAmoled => _isAmoled;
  bool get useGlassmorphism => _useGlassmorphism;
  Locale? get locale => _locale;
  bool get use24HourFormat => _use24HourFormat;
  bool get enableReminders => _enableReminders;

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
    _useGlassmorphism = prefs.getBool(_keyUseGlassmorphism) ?? true;
    _use24HourFormat = prefs.getBool(_keyUse24HourFormat) ?? true;
    _enableReminders = prefs.getBool(_keyEnableReminders) ?? true;

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

  Future<void> setUseGlassmorphism(bool value) async {
    if (_useGlassmorphism == value) return;
    _useGlassmorphism = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseGlassmorphism, value);
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

  Future<void> setUse24HourFormat(bool value) async {
    if (_use24HourFormat == value) return;
    _use24HourFormat = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUse24HourFormat, value);
  }

  Future<void> setEnableReminders(bool value) async {
    if (_enableReminders == value) return;
    _enableReminders = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableReminders, value);
  }
}
