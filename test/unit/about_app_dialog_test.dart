import 'package:rocis_schedule/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/profile/widgets/about_app_dialog.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget(ThemeProvider themeProvider) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizationsDelegate()],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AboutAppDialog()),
      ),
    );
  }

  group('AboutAppDialog Tests', () {
    testWidgets('Renders app title, version, and links', (tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpWidget(buildTestWidget(themeProvider));
      await tester.pumpAndSettle();

      expect(find.text('ROCIs Schedule'), findsOneWidget);
      expect(find.text('v${AppConfig.appVersion}'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
      expect(find.byIcon(Icons.code_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);

      // Beta features should initially be hidden
      expect(find.text('Beta Features'), findsNothing);
    });

    testWidgets(
      'Tapping version 5 times unlocks Beta features via Easter egg',
      (tester) async {
        final themeProvider = ThemeProvider();
        await tester.pumpWidget(buildTestWidget(themeProvider));
        await tester.pumpAndSettle();

        expect(themeProvider.betaFeaturesUnlocked, isFalse);
        expect(find.text('Beta Features'), findsNothing);

        final versionFinder = find.text('v${AppConfig.appVersion}');
        for (int i = 0; i < 5; i++) {
          await tester.tap(versionFinder);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        expect(themeProvider.betaFeaturesUnlocked, isTrue);
        expect(find.text('Beta Features'), findsOneWidget);
        expect(find.text('ROCIs Tasks Synergy (Beta)'), findsOneWidget);
      },
    );

    testWidgets('Toggling ROCIs Tasks Synergy updates ThemeProvider state', (
      tester,
    ) async {
      final themeProvider = ThemeProvider();
      await themeProvider.setBetaFeaturesUnlocked(true);

      await tester.pumpWidget(buildTestWidget(themeProvider));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(themeProvider.enableTasksIntegration, isFalse);

      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(themeProvider.enableTasksIntegration, isTrue);
      expect(
        find.text('Cloud Sync connected with ROCIs Tasks'),
        findsOneWidget,
      );
    });
  });
}
