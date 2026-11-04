import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_source.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_config.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

/// Opens the Afeka feed link in a browser so the user can sign in. Each time a
/// page finishes loading, the session cookies are tried against the feed; the
/// first time it returns a calendar they are saved and the screen closes with
/// `true`. Credentials are typed into Afeka's own page and never seen here.
class AfekaLoginScreen extends StatefulWidget {
  final Uri feedUrl;
  final SyncConfig config;

  const AfekaLoginScreen({
    super.key,
    required this.feedUrl,
    required this.config,
  });

  @override
  State<AfekaLoginScreen> createState() => _AfekaLoginScreenState();
}

class _AfekaLoginScreenState extends State<AfekaLoginScreen> {
  bool _checking = false;
  bool _done = false;

  Future<void> _tryCapture() async {
    if (_checking || _done) return;
    _checking = true;
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri.uri(widget.feedUrl),
      );
      if (cookies.isEmpty) return;
      final header = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      final result = await AfekaSource(
        widget.feedUrl,
        () async => header,
      ).fetch();
      if (result is FetchOk && mounted) {
        _done = true;
        await widget.config.saveCookieHeader(header);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      // Not signed in yet: keep the page open.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('calendar_sync_sign_in'))),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(widget.feedUrl)),
        onLoadStop: (controller, url) => _tryCapture(),
        onDownloadStartRequest: (controller, request) => _tryCapture(),
      ),
    );
  }
}
