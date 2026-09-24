/// App-wide constants.
class AppConfig {
  AppConfig._();

  /// Shown in Settings and About. Kept in sync with `pubspec.yaml` by the
  /// release script (`bump_version.py`), so don't edit it by hand.
  static const String appVersion = '0.0.5';
}
