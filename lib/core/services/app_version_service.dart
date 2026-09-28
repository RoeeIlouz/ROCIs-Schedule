import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'package:rocis_schedule/core/config/app_config.dart';

/// The version shown to users: `0.0.7`, or `0.0.7 P2` while Shorebird patch 2
/// is running. The patch number comes from the updater, so it always matches
/// what the device actually runs (a downloaded patch applies on next launch).
class AppVersionService {
  AppVersionService._();

  static Future<String>? _label;

  static Future<String> label() => _label ??= _readLabel();

  static Future<String> _readLabel() async {
    try {
      final updater = ShorebirdUpdater();
      // Unavailable in debug builds, on web and in tests.
      if (!updater.isAvailable) return AppConfig.appVersion;
      final patch = await updater.readCurrentPatch();
      return patch == null
          ? AppConfig.appVersion
          : '${AppConfig.appVersion} P${patch.number}';
    } catch (_) {
      return AppConfig.appVersion;
    }
  }
}

/// `v0.0.7` / `v0.0.7 P2`, starting with the plain version until the patch
/// number has been read.
class AppVersionText extends StatelessWidget {
  final TextStyle? style;

  const AppVersionText({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AppVersionService.label(),
      initialData: AppConfig.appVersion,
      builder: (context, snapshot) =>
          Text('v${snapshot.data ?? AppConfig.appVersion}', style: style),
    );
  }
}
