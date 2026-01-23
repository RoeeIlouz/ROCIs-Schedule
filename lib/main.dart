import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/theme/app_theme.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/router.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/friends/friend_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:rocis_schedule/shared/services/sync_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await NotificationService().init();

  final authService = AuthService();
  final themeProvider = ThemeProvider();

  runApp(MyApp(authService: authService, themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final ThemeProvider themeProvider;

  const MyApp({
    super.key,
    required this.authService,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProxyProvider<AuthService, CourseProvider?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (auth.user == null) return null;
            if (previous?.userId == auth.user!.uid) return previous;
            return CourseProvider(auth.user!.uid)..loadData();
          },
        ),
        ChangeNotifierProxyProvider<AuthService, AssignmentProvider?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (auth.user == null) return null;
            if (previous?.uid == auth.user!.uid) return previous;
            return AssignmentProvider(auth.user!.uid)..loadAssignments();
          },
        ),
        ChangeNotifierProxyProvider<AuthService, FriendProvider?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (auth.user == null) return null;
            if (previous?.uid == auth.user!.uid) return previous;
            return FriendProvider(auth.user!.uid)..loadFriends();
          },
        ),
        ProxyProvider3<
          AuthService,
          CourseProvider?,
          AssignmentProvider?,
          SyncService?
        >(
          update: (_, auth, courses, assignments, previous) {
            if (auth.user == null || courses == null || assignments == null) {
              return null;
            }
            if (previous != null) return previous;
            return SyncService(auth, courses, assignments);
          },
          dispose: (_, sync) => sync?.dispose(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme? lightScheme;
              ColorScheme? darkScheme;

              if (themeProvider.useDynamicColor) {
                lightScheme = lightDynamic;
                darkScheme = darkDynamic;
              }

              return MaterialApp.router(
                title: 'ROCIs Schedule',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme(lightScheme),
                darkTheme: AppTheme.darkTheme(
                  darkScheme,
                  isAmoled: themeProvider.isAmoled,
                ),
                themeMode: themeProvider.themeMode,
                routerConfig: AppRouter.router,
                locale: themeProvider.locale,
                localizationsDelegates: const [
                  AppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en', ''), Locale('he', '')],
              );
            },
          );
        },
      ),
    );
  }
}
