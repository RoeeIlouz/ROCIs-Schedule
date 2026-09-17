import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

void main() {
  group('Multilingual Localization Suite (8 Languages)', () {
    test('supportedLocales contains all 8 target languages', () {
      final supportedCodes = AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toList();

      expect(
        supportedCodes,
        containsAll(['en', 'he', 'es', 'de', 'fr', 'ar', 'hi', 'sv']),
      );
      expect(supportedCodes.length, 8);
    });

    for (final code in ['en', 'he', 'es', 'de', 'fr', 'ar', 'hi', 'sv']) {
      test('Language "$code" translates core keys accurately', () {
        final l10n = AppLocalizations(Locale(code));

        expect(l10n.translate('app_title'), 'ROCIs Schedule');
        expect(l10n.translate('schedule').isNotEmpty, isTrue);
        expect(l10n.translate('assignments').isNotEmpty, isTrue);
        expect(l10n.translate('my_courses').isNotEmpty, isTrue);
        expect(l10n.translate('settings').isNotEmpty, isTrue);
        expect(l10n.translate('sign_in').isNotEmpty, isTrue);
        expect(l10n.translate('guest_mode_title').isNotEmpty, isTrue);
        expect(l10n.translate('send_to_tasks').isNotEmpty, isTrue);
        expect(l10n.translate('semester').isNotEmpty, isTrue);
        expect(l10n.translate('accent_color').isNotEmpty, isTrue);
        expect(l10n.translate('clear_cache_title').isNotEmpty, isTrue);
      });
    }

    test('All 8 supported languages have 100% key parity with English', () {
      final enMap = AppLocalizations.localizedValues['en']!;
      final allLocales = ['he', 'es', 'de', 'fr', 'ar', 'hi', 'sv'];

      for (final code in allLocales) {
        final langMap = AppLocalizations.localizedValues[code];
        expect(
          langMap,
          isNotNull,
          reason: 'Language $code must have localized values map',
        );

        final missingKeys = <String>[];
        for (final key in enMap.keys) {
          if (!langMap!.containsKey(key)) {
            missingKeys.add(key);
          }
        }
        expect(
          missingKeys,
          isEmpty,
          reason: 'Language $code missing keys: $missingKeys',
        );
        expect(
          langMap!.length,
          enMap.length,
          reason: 'Language $code has different key count than English',
        );
      }
    });

    test(
      'No localized string in any of the 8 languages is empty or whitespace only',
      () {
        for (final entry in AppLocalizations.localizedValues.entries) {
          final lang = entry.key;
          for (final item in entry.value.entries) {
            expect(
              item.value.trim().isNotEmpty,
              isTrue,
              reason: 'Language "$lang" has empty string for key "${item.key}"',
            );
          }
        }
      },
    );

    test('Delegate supports all 8 locales and falls back gracefully', () {
      const delegate = AppLocalizationsDelegate();
      for (final code in ['en', 'he', 'es', 'de', 'fr', 'ar', 'hi', 'sv']) {
        expect(delegate.isSupported(Locale(code)), isTrue);
      }
      expect(delegate.isSupported(const Locale('ja')), isFalse);
    });
  });
}
