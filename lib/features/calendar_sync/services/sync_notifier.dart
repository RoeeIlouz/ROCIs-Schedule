import 'package:intl/intl.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_sync_service.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';

/// Shows sync results as local notifications. [tr] is `l10n.translate` (or a
/// locale-only equivalent in a background isolate).
class LocalSyncNotifier implements SyncNotifier {
  static const changesId = 7101;
  static const loginId = 7102;
  static const maxLines = 6;

  final String Function(String key) tr;

  LocalSyncNotifier(this.tr);

  static String keyFor(ChangeKind kind) => switch (kind) {
    ChangeKind.added => 'sync_change_added',
    ChangeKind.removed => 'sync_change_removed',
    ChangeKind.moved => 'sync_change_moved',
    ChangeKind.roomChanged => 'sync_change_room',
    ChangeKind.lecturerChanged => 'sync_change_lecturer',
    ChangeKind.cancelled => 'sync_change_cancelled',
    ChangeKind.restored => 'sync_change_restored',
  };

  /// One line per change: `Label: course, d/M HH:mm (detail)`.
  String line(SyncChange c) {
    final when = DateFormat('d/M HH:mm').format(c.when);
    final String detail;
    if (c.kind == ChangeKind.moved && c.detail != null) {
      final old = DateTime.tryParse(c.detail!);
      detail = old == null
          ? ''
          : ' (${DateFormat('d/M HH:mm').format(old)} -> $when)';
    } else {
      detail = c.detail == null ? '' : ' (${c.detail})';
    }
    return '${tr(keyFor(c.kind))}: ${c.course}, $when$detail';
  }

  String body(List<SyncChange> changes) {
    final lines = changes.take(maxLines).map(line).toList();
    final more = changes.length - lines.length;
    if (more > 0) lines.add('+$more');
    return lines.join('\n');
  }

  @override
  Future<void> changes(List<SyncChange> changes) =>
      NotificationService().showNow(
        id: changesId,
        title: tr('calendar_sync_changed_title'),
        body: body(changes),
      );

  @override
  Future<void> loginExpired() => NotificationService().showNow(
    id: loginId,
    title: tr('calendar_sync_login_title'),
    body: tr('calendar_sync_needs_login'),
  );
}
