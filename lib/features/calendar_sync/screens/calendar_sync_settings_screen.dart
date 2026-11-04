import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/calendar_sync/screens/afeka_login_screen.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_sync_service.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_config.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_notifier.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_scheduler.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_store.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

class CalendarSyncSettingsScreen extends StatefulWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  State<CalendarSyncSettingsScreen> createState() =>
      _CalendarSyncSettingsScreenState();
}

class _CalendarSyncSettingsScreenState
    extends State<CalendarSyncSettingsScreen> {
  final _config = SyncConfig();
  final _store = SyncStore();
  final _url = TextEditingController();
  SyncKind _kind = SyncKind.afeka;
  bool _busy = false;
  bool _hasCookie = false;
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final kind = await _config.kind();
    final url = await _config.feedUrl();
    final cookie = await _config.cookieHeader();
    final source = await _config.buildSource();
    final last = source == null ? null : await _store.lastSync(source.id);
    if (!mounted) return;
    setState(() {
      if (kind != SyncKind.off) _kind = kind;
      _url.text = url ?? '';
      _hasCookie = cookie != null;
      _last = last;
    });
  }

  Future<bool> _save(CourseProvider provider) async {
    final url = Uri.tryParse(_url.text.trim());
    if (url == null || !url.hasScheme || url.host.isEmpty) return false;
    await _config.enable(
      kind: _kind,
      userId: provider.userId,
      feedUrl: url.toString(),
    );
    return true;
  }

  Future<void> _signIn(CourseProvider provider) async {
    if (!await _save(provider) || !mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AfekaLoginScreen(
          feedUrl: Uri.parse(_url.text.trim()),
          config: _config,
        ),
      ),
    );
    if (ok == true) {
      await SyncScheduler.registerPeriodic();
      await _load();
      if (mounted) await _syncNow(provider);
    }
  }

  Future<void> _syncNow(CourseProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _save(provider)) return;
    setState(() => _busy = true);
    try {
      final source = await _config.buildSource();
      if (source == null) return;
      final service = CalendarSyncService(
        provider,
        _store,
        cancelledLabel: l10n.translate('calendar_sync_cancelled'),
      );
      final result = await service.run(
        source,
        LocalSyncNotifier(l10n.translate),
      );
      if (_kind == SyncKind.publicIcs) await SyncScheduler.registerPeriodic();
      final candidates = result.summary?.replaceCandidates ?? const [];
      if (candidates.isNotEmpty && mounted) {
        await _offerReplace(service, candidates.map((e) => e.id).toList());
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (result.status) {
            SyncRunStatus.ok => l10n.translate('calendar_sync_done'),
            SyncRunStatus.needsLogin => l10n.translate(
              'calendar_sync_needs_login',
            ),
            SyncRunStatus.failed => l10n.translate('calendar_sync_failed'),
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _offerReplace(CalendarSyncService svc, List<String> ids) async {
    final l10n = AppLocalizations.of(context)!;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('calendar_sync_replace_title')),
        content: Text(l10n.translate('calendar_sync_replace_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('calendar_sync_keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('calendar_sync_replace')),
          ),
        ],
      ),
    );
    if (replace == true) await svc.applyReplacement(ids);
  }

  Future<void> _turnOff() async {
    await _config.disable();
    await SyncScheduler.cancel();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<CourseProvider>();
    final last = _last == null
        ? l10n.translate('calendar_sync_never')
        : DateFormat('d/M/y HH:mm').format(_last!);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('calendar_sync'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<SyncKind>(
            segments: [
              ButtonSegment(
                value: SyncKind.afeka,
                label: Text(l10n.translate('calendar_sync_afeka')),
              ),
              ButtonSegment(
                value: SyncKind.publicIcs,
                label: Text(l10n.translate('calendar_sync_public')),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            obscureText: _kind == SyncKind.afeka,
            decoration: InputDecoration(
              labelText: l10n.translate('calendar_sync_feed_url'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_kind == SyncKind.afeka)
            FilledButton.icon(
              onPressed: _busy ? null : () => _signIn(provider),
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.translate('calendar_sync_sign_in')),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy || (_kind == SyncKind.afeka && !_hasCookie)
                ? null
                : () => _syncNow(provider),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(l10n.translate('calendar_sync_now')),
          ),
          const SizedBox(height: 16),
          Text('${l10n.translate('calendar_sync_last')}: $last'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _turnOff,
            child: Text(l10n.translate('calendar_sync_off')),
          ),
        ],
      ),
    );
  }
}
