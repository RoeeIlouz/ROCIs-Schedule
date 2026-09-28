import 'package:web/web.dart' as web;

/// Replaces the address bar URL without reloading (e.g. drop a handled
/// `/share?d=…` so a refresh doesn't reopen the import).
void replaceBrowserUrl(String url) {
  web.window.history.replaceState(null, '', url);
}
