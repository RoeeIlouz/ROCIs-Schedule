import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/main.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(
        authService: AuthService(),
        themeProvider: ThemeProvider(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the login screen is shown (it has the app name)
    expect(find.text('ROCIs Schedule'), findsOneWidget);
  });
}
