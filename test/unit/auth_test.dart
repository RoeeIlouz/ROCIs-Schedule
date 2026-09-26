import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/features/auth/register_screen.dart';
import 'package:rocis_schedule/features/profile/profile_screen.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/sync_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      Provider<FirestoreService>(create: (_) => FirestoreService()),
      Provider<SyncService?>(create: (_) => null),
    ],
    child: MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate()],
      supportedLocales: const [Locale('en'), Locale('he')],
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication & Guest Mode Suite', () {
    test('AuthService guest mode getters behave as expected', () {
      final auth = AuthService();
      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.effectiveUserId, 'guest');
    });

    testWidgets(
      'LoginScreen renders email, password, Google button and close button',
      (tester) async {
        await tester.pumpWidget(createTestApp(const LoginScreen()));
        await tester.pumpAndSettle();

        expect(
          find.byType(TextFormField),
          findsNWidgets(2),
        ); // Email & Password
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
      },
    );

    testWidgets('RegisterScreen validates empty email and password', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byType(TextFormField),
        findsNWidgets(3),
      ); // Email, Password, Confirm
      expect(find.text('Create Account'), findsWidgets);

      // Tap create without filling fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets(
      'ProfileScreen renders Guest Mode state gracefully when user is not logged in',
      (tester) async {
        await tester.pumpWidget(createTestApp(const ProfileScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Guest Mode'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );
  });
}
