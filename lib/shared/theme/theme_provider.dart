import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyUseDynamicColor = 'use_dynamic_color';
  static const String _keyIsAmoled = 'is_amoled';
  static const String _keyUseGlassmorphism = 'use_glassmorphism';
  static const String _keyLocale = 'locale';
  static const String _keyUse24HourFormat = 'use_24_hour_format';
  static const String _keyEnableReminders = 'enable_reminders';
  static const String _keyCustomSeedColor = 'custom_seed_color';
  static const String _keyReminderLeadMinutes = 'reminder_lead_minutes';
  static const String _keyEnableTasksIntegration = 'beta_tasks_integration';
  static const String _keyBetaFeaturesUnlocked = 'beta_features_unlocked';
  static const String _keySelectedPresetId = 'selected_preset_id';

  static const Color brandSeed = Color(0xFF0E6FA8);

  static const List<ThemePreset> presets = [
    ThemePreset(
      id: 'rocis',
      name: 'ROCIs Ocean',
      primaryColor: brandSeed,
      secondaryColor: Color(0xFF16B5C9),
      icon: Icons.calendar_month_rounded,
    ),
    ThemePreset(
      id: 'indigo',
      name: 'Indigo Modern',
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFF0EA5E9),
      icon: Icons.auto_awesome_rounded,
    ),
    ThemePreset(
      id: 'teal',
      name: 'Teal Focus',
      primaryColor: Color(0xFF0D9488),
      secondaryColor: Color(0xFF14B8A6),
      icon: Icons.spa_rounded,
    ),
    ThemePreset(
      id: 'cobalt',
      name: 'Ocean Cobalt',
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF38BDF8),
      icon: Icons.water_drop_rounded,
    ),
    ThemePreset(
      id: 'emerald',
      name: 'Emerald Forest',
      primaryColor: Color(0xFF059669),
      secondaryColor: Color(0xFF10B981),
      icon: Icons.park_rounded,
    ),
    ThemePreset(
      id: 'amber',
      name: 'Sunset Amber',
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFFB923C),
      icon: Icons.wb_sunny_rounded,
    ),
    ThemePreset(
      id: 'coral',
      name: 'Rose Coral',
      primaryColor: Color(0xFFF43F5E),
      secondaryColor: Color(0xFFFB7185),
      icon: Icons.favorite_rounded,
    ),
    ThemePreset(
      id: 'violet',
      name: 'Royal Violet',
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFA78BFA),
      icon: Icons.psychology_rounded,
    ),
    ThemePreset(
      id: 'slate',
      name: 'Minimal Slate',
      primaryColor: Color(0xFF64748B),
      secondaryColor: Color(0xFF94A3B8),
      icon: Icons.architecture_rounded,
    ),
  ];

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = false;
  bool _isAmoled = false;
  bool _useGlassmorphism = true;
  Locale? _locale;
  bool _use24HourFormat = true;
  bool _enableReminders = true;
  Color _customSeedColor = brandSeed;
  int _reminderLeadMinutes = 15;
  bool _enableTasksIntegration = false;
  bool _betaFeaturesUnlocked = false;
  String? _selectedPresetId;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => !kIsWeb && _useDynamicColor;
  bool get isAmoled => _isAmoled;
  bool get useGlassmorphism => !kIsWeb && _useGlassmorphism;
  Locale? get locale => _locale;
  bool get use24HourFormat => _use24HourFormat;
  bool get enableReminders => _enableReminders;
  Color get customSeedColor => _customSeedColor;
  int get reminderLeadMinutes => _reminderLeadMinutes;
  bool get enableTasksIntegration => _enableTasksIntegration;
  bool get betaFeaturesUnlocked => _betaFeaturesUnlocked;
  String? get selectedPresetId => _selectedPresetId;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final modeIndex = prefs.getInt(_keyThemeMode);
    if (modeIndex != null) {
      _themeMode = ThemeMode.values[modeIndex];
    }

    _useDynamicColor = prefs.getBool(_keyUseDynamicColor) ?? false;
    _isAmoled = prefs.getBool(_keyIsAmoled) ?? false;
    _useGlassmorphism = prefs.getBool(_keyUseGlassmorphism) ?? true;
    _use24HourFormat = prefs.getBool(_keyUse24HourFormat) ?? true;
    _enableReminders = prefs.getBool(_keyEnableReminders) ?? true;

    final colorVal = prefs.getInt(_keyCustomSeedColor);
    if (colorVal != null) {
      _customSeedColor = Color(colorVal);
    }
    _reminderLeadMinutes = prefs.getInt(_keyReminderLeadMinutes) ?? 15;
    _enableTasksIntegration =
        prefs.getBool(_keyEnableTasksIntegration) ?? false;
    _betaFeaturesUnlocked = prefs.getBool(_keyBetaFeaturesUnlocked) ?? false;
    _selectedPresetId = prefs.getString(_keySelectedPresetId);

    if (_selectedPresetId == null && !_useDynamicColor) {
      for (final p in presets) {
        if (p.primaryColor.toARGB32() == _customSeedColor.toARGB32()) {
          _selectedPresetId = p.id;
          break;
        }
      }
    }

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
    if (value) {
      _selectedPresetId = null;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDynamicColor, value);
    if (value) {
      await prefs.remove(_keySelectedPresetId);
    }
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

  Future<void> applyPreset(ThemePreset preset) async {
    _customSeedColor = preset.primaryColor;
    _selectedPresetId = preset.id;
    _useDynamicColor = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomSeedColor, preset.primaryColor.toARGB32());
    await prefs.setString(_keySelectedPresetId, preset.id);
    await prefs.setBool(_keyUseDynamicColor, false);
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

  Future<void> setCustomSeedColor(Color color) async {
    if (_customSeedColor == color && !_useDynamicColor) return;
    _customSeedColor = color;
    _useDynamicColor = false;
    _selectedPresetId = null;
    for (final p in presets) {
      if (p.primaryColor.toARGB32() == color.toARGB32()) {
        _selectedPresetId = p.id;
        break;
      }
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomSeedColor, color.toARGB32());
    await prefs.setBool(_keyUseDynamicColor, false);
    if (_selectedPresetId != null) {
      await prefs.setString(_keySelectedPresetId, _selectedPresetId!);
    } else {
      await prefs.remove(_keySelectedPresetId);
    }
  }

  Future<void> setReminderLeadMinutes(int minutes) async {
    if (_reminderLeadMinutes == minutes) return;
    _reminderLeadMinutes = minutes;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderLeadMinutes, minutes);
  }

  Future<void> setEnableTasksIntegration(bool value) async {
    if (_enableTasksIntegration == value) return;
    _enableTasksIntegration = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableTasksIntegration, value);
  }

  Future<void> setBetaFeaturesUnlocked(bool value) async {
    if (_betaFeaturesUnlocked == value) return;
    _betaFeaturesUnlocked = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBetaFeaturesUnlocked, value);
  }
}
