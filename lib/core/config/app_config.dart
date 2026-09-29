/// App-wide constants.
class AppConfig {
  AppConfig._();

  /// Shown in Settings and About. Kept in sync with `pubspec.yaml` by the
  /// release script (`bump_version.py`), so don't edit it by hand.
  static const String appVersion = '0.0.8';

  /// Set by CI with `--dart-define=DISTRIBUTION=github` for APKs published on
  /// GitHub Releases. Those builds aren't signed by Google Play, so native
  /// Google Sign-In (which needs an ownership-verified Android OAuth client)
  /// can't work; they sign in through Firebase's browser flow instead.
  static const bool isGithubBuild =
      String.fromEnvironment('DISTRIBUTION') == 'github';
}
