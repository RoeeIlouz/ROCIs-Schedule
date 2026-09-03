import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

void main() {
  group('Multilingual Localization Suite (8 Languages)', () {
    test('supportedLocales contains all 8 target languages', () {
      final supportedCodes =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toList();

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
      });
    }

    test('Delegate supports all 8 locales and falls back gracefully', () {
      const delegate = AppLocalizationsDelegate();
      for (final code in ['en', 'he', 'es', 'de', 'fr', 'ar', 'hi', 'sv']) {
        expect(delegate.isSupported(Locale(code)), isTrue);
      }
      expect(delegate.isSupported(const Locale('ja')), isFalse);
    });
  });
}
