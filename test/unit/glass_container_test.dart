import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GlassContainer Widget Tests', () {
    testWidgets('renders child content with GlassContainer', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: GlassContainer(
                color: Colors.blue,
                child: Text('Test Glass Text'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Glass Text'), findsOneWidget);
    });

    testWidgets('renders correctly when glassmorphism is disabled', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await themeProvider.setUseGlassmorphism(false);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: GlassContainer(
                color: Colors.orange,
                child: Text('Non-Glass Text'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Non-Glass Text'), findsOneWidget);
    });
  });
}
