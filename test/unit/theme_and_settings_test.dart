import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider & Settings Persistence Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial preferences load sensible defaults', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isAmoled, isFalse);
      expect(provider.useGlassmorphism, isTrue);
      expect(provider.useDynamicColor, isTrue);
      expect(provider.use24HourFormat, isTrue);
      expect(provider.enableReminders, isTrue);
      expect(provider.locale, isNull);
    });

    test('ThemeMode changes persist to SharedPreferences', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_mode'), ThemeMode.dark.index);

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
    });

    test('Toggling AMOLED mode persists properly', () async {
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.setIsAmoled(true);
      expect(provider.isAmoled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_amoled'), isTrue);

      await provider.setIsAmoled(false);
      expect(provider.isAmoled, isFalse);
      expect(prefs.getBool('is_amoled'), isFalse);
    });

    test(
      'Toggling Glassmorphism, Dynamic Color, 24h format and Reminders persist',
      () async {
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        await provider.setUseGlassmorphism(false);
        expect(provider.useGlassmorphism, isFalse);

        await provider.setUseDynamicColor(false);
        expect(provider.useDynamicColor, isFalse);

        await provider.setUse24HourFormat(false);
        expect(provider.use24HourFormat, isFalse);

        await provider.setEnableReminders(false);
        expect(provider.enableReminders, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('use_glassmorphism'), isFalse);
        expect(prefs.getBool('use_dynamic_color'), isFalse);
        expect(prefs.getBool('use_24_hour_format'), isFalse);
        expect(prefs.getBool('enable_reminders'), isFalse);
      },
    );

    test(
      'Switching across all 8 supported locales updates state and persists language code',
      () async {
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        final languages = ['en', 'he', 'es', 'de', 'fr', 'ar', 'hi', 'sv'];

        for (final code in languages) {
          await provider.setLocale(Locale(code));
          expect(provider.locale?.languageCode, code);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('locale'), code);
        }

        // Reset to system (null)
        await provider.setLocale(null);
        expect(provider.locale, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('locale'), isFalse);
      },
    );

    test(
      'Toggling Beta Features and ROCIs Tasks Integration updates state and persists',
      () async {
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        // Initial defaults
        expect(provider.betaFeaturesUnlocked, isFalse);
        expect(provider.enableTasksIntegration, isFalse);

        // Unlock Beta Features via Easter egg
        await provider.setBetaFeaturesUnlocked(true);
        expect(provider.betaFeaturesUnlocked, isTrue);

        // Enable Tasks integration
        await provider.setEnableTasksIntegration(true);
        expect(provider.enableTasksIntegration, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('beta_features_unlocked'), isTrue);
        expect(prefs.getBool('beta_tasks_integration'), isTrue);

        // Verify state is restored upon reload
        final newProvider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 50));
        expect(newProvider.betaFeaturesUnlocked, isTrue);
        expect(newProvider.enableTasksIntegration, isTrue);
      },
    );

    test(
      'Applying curated theme presets updates customSeedColor and selectedPresetId',
      () async {
        final provider = ThemeProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(ThemeProvider.presets, isNotEmpty);
        expect(ThemeProvider.presets.length, equals(8));

        final tealPreset = ThemeProvider.presets.firstWhere(
          (p) => p.id == 'teal',
        );
        await provider.applyPreset(tealPreset);

        expect(provider.selectedPresetId, 'teal');
        expect(provider.customSeedColor, tealPreset.primaryColor);
        expect(provider.useDynamicColor, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('selected_preset_id'), 'teal');
        expect(
          prefs.getInt('custom_seed_color'),
          tealPreset.primaryColor.toARGB32(),
        );
        expect(prefs.getBool('use_dynamic_color'), isFalse);

        // Custom color clears preset id
        await provider.setCustomSeedColor(const Color(0xFFFF5722));
        expect(provider.customSeedColor, const Color(0xFFFF5722));
        expect(provider.selectedPresetId, isNull);
      },
    );
  });
}
