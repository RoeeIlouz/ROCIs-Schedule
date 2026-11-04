import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_sync_service.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_config.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_notifier.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_store.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/firebase_options.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _uniqueName = 'calendar-sync';
const _taskName = 'calendarSync';
const _platformTimeout = Duration(seconds: 2);

/// Background entry point. Skips all UI setup: only what sync needs.
@pragma('vm:entry-point')
void calendarSyncDispatcher() {
  Workmanager().executeTask((task, inputData) => SyncScheduler.runBackground());
}

class SyncScheduler {
  static const interval = Duration(hours: 6);

  static bool isDue(
    DateTime? lastSync,
    DateTime now, {
    Duration interval = interval,
  }) => lastSync == null || now.difference(lastSync) >= interval;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> registerPeriodic() async {
    if (!_supported) return;
    try {
      await Workmanager().initialize(calendarSyncDispatcher);
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: interval,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (e) {
      debugPrint('SyncScheduler: register failed: $e');
    }
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
    } catch (e) {
      debugPrint('SyncScheduler: cancel failed: $e');
    }
  }

  static Future<AppLocalizations> _l10n() async {
    final code = (await SharedPreferences.getInstance()).getString('locale');
    return AppLocalizations(Locale(code ?? 'en'));
  }

  /// Runs one sync in the background isolate. Returns true so the OS does not
  /// retry on a plain failure (the next period tries again).
  static Future<bool> runBackground() async {
    try {
      final config = SyncConfig();
      final source = await config.buildSource();
      final uid = await config.userId();
      if (source == null || uid == null) return true;

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_platformTimeout);
      await NotificationService().init().timeout(_platformTimeout);

      final l10n = await _l10n();
      final provider = CourseProvider(uid);
      await provider.loadData();
      final service = CalendarSyncService(
        provider,
        SyncStore(),
        cancelledLabel: l10n.translate('calendar_sync_cancelled'),
        autoCreateCourses: false,
      );
      await service.run(source, LocalSyncNotifier(l10n.translate));
    } catch (e) {
      debugPrint('SyncScheduler: background run failed: $e');
    }
    return true;
  }

  /// Called when the app opens: syncs if the last sync is older than
  /// [interval]. Safe to call often.
  static Future<void> syncIfDue(
    CourseProvider provider,
    AppLocalizations l10n,
  ) async {
    try {
      final config = SyncConfig();
      final source = await config.buildSource();
      if (source == null) return;
      if (!isDue(await SyncStore().lastSync(source.id), DateTime.now())) return;
      await CalendarSyncService(
        provider,
        SyncStore(),
        cancelledLabel: l10n.translate('calendar_sync_cancelled'),
        autoCreateCourses: false,
      ).run(source, LocalSyncNotifier(l10n.translate));
    } catch (e) {
      debugPrint('SyncScheduler: syncIfDue failed: $e');
    }
  }
}
