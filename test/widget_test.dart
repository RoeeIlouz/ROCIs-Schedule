import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/main.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/features/schedule/schedule_screen.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

void main() {
  testWidgets('App opens on the schedule, not a login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(authService: AuthService(), themeProvider: ThemeProvider()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
