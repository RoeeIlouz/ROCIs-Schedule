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

  group('GlassContainer Polish & Tinting Tests', () {
    testWidgets('renders BackdropFilter when glassmorphism is active', (tester) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: GlassContainer(
                tintColor: Color(0xFF6366F1),
                child: Text('Glass Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Glass Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('renders surfaceContainerLow fallback and respects custom border when glass is disabled', (tester) async {
      final themeProvider = ThemeProvider();
      await themeProvider.setUseGlassmorphism(false);

      const customBorder = Border.fromBorderSide(
        BorderSide(color: Colors.red, width: 2.0),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            ),
            home: const Scaffold(
              body: GlassContainer(
                tintColor: Colors.blue,
                border: customBorder,
                child: Text('Non-Glass Fallback'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Non-Glass Fallback'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      final container = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(GlassContainer),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((c) => c.decoration != null);

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, equals(customBorder));
    });
  });
}
