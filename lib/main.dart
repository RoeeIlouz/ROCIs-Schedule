import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:rocis_schedule/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/theme/app_theme.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/router.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/tasks/synced_tasks_provider.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/google_calendar_sync_service.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:rocis_schedule/shared/services/sync_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('main(): Firebase initialization error: $e');
  }

  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('main(): NotificationService initialization error: $e');
  }

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
        ChangeNotifierProxyProvider<AuthService, CourseProvider>(
          create: (context) {
            final auth = context.read<AuthService>();
            return CourseProvider(auth.effectiveUserId)..loadData();
          },
          update: (_, auth, previous) {
            final uid = auth.effectiveUserId;
            if (previous != null && previous.userId == uid) return previous;
            return CourseProvider(uid)..loadData();
          },
        ),
        ChangeNotifierProxyProvider<AuthService, AssignmentProvider>(
          create: (context) {
            final auth = context.read<AuthService>();
            return AssignmentProvider(auth.effectiveUserId)..loadAssignments();
          },
          update: (_, auth, previous) {
            final uid = auth.effectiveUserId;
            if (previous != null && previous.uid == uid) return previous;
            return AssignmentProvider(uid)..loadAssignments();
          },
        ),
        ChangeNotifierProxyProvider<AuthService, SyncedTasksProvider>(
          create: (context) {
            final auth = context.read<AuthService>();
            return SyncedTasksProvider(
              email: auth.user?.email,
              uid: auth.user?.uid,
            );
          },
          update: (_, auth, previous) {
            final email = auth.user?.email;
            final uid = auth.user?.uid;
            // AuthService notifies often; only refetch when the user changes.
            if (previous != null &&
                previous.email == email &&
                previous.uid == uid) {
              return previous;
            }
            return SyncedTasksProvider(email: email, uid: uid);
          },
        ),
        ChangeNotifierProxyProvider2<
          CourseProvider,
          ThemeProvider,
          GoogleCalendarSyncService
        >(
          create: (context) =>
              GoogleCalendarSyncService(context.read<AuthService>()),
          update: (_, courses, theme, sync) => sync!..attach(courses, theme),
        ),
        ProxyProvider3<
          AuthService,
          CourseProvider,
          AssignmentProvider,
          SyncService?
        >(
          update: (_, auth, courses, assignments, previous) {
            if (auth.user == null) {
              previous?.dispose();
              return null;
            }
            if (previous != null) {
              return previous;
            }
            final syncService = SyncService(auth, courses, assignments);
            syncService.performInitialSync();
            return syncService;
          },
          dispose: (_, sync) => sync?.dispose(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              final ColorScheme lightScheme =
                  (themeProvider.useDynamicColor && lightDynamic != null)
                  ? lightDynamic
                  : themeProvider.customSeedColor == ThemeProvider.brandSeed
                  ? AppTheme.brandScheme(Brightness.light)
                  : ColorScheme.fromSeed(
                      seedColor: themeProvider.customSeedColor,
                      brightness: Brightness.light,
                    );
              final ColorScheme darkScheme =
                  (themeProvider.useDynamicColor && darkDynamic != null)
                  ? darkDynamic
                  : themeProvider.customSeedColor == ThemeProvider.brandSeed
                  ? AppTheme.brandScheme(Brightness.dark)
                  : ColorScheme.fromSeed(
                      seedColor: themeProvider.customSeedColor,
                      brightness: Brightness.dark,
                    );

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
                supportedLocales: AppLocalizations.supportedLocales,
                localeResolutionCallback: (locale, supportedLocales) {
                  if (locale == null) return const Locale('en', '');
                  for (final supportedLocale in supportedLocales) {
                    if (supportedLocale.languageCode == locale.languageCode) {
                      return supportedLocale;
                    }
                  }
                  return const Locale('en', '');
                },
              );
            },
          );
        },
      ),
    );
  }
}
