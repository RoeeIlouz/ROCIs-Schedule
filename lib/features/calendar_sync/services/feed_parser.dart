import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';

/// Parses iCalendar text into raw [FeedEntry]s. Never throws on bad input.
class FeedParser {
  /// True when [body] is a calendar and not, say, an HTML login page.
  static bool looksLikeCalendar(String body) {
    final trimmed = body.replaceFirst('\uFEFF', '').trimLeft();
    return trimmed.startsWith('BEGIN:VCALENDAR');
  }

  static List<FeedEntry> parse(String ics) {
    if (!looksLikeCalendar(ics)) return const [];
    final lines = _unfold(ics);
    final out = <FeedEntry>[];
    Map<String, String>? props;

    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        props = {};
      } else if (line == 'END:VEVENT') {
        final p = props;
        props = null;
        if (p == null) continue;
        final start = _date(p['DTSTART']);
        if (start == null) continue;
        out.add(FeedEntry(
          uid: p['UID'] ?? '',
          summary: _text(p['SUMMARY'] ?? ''),
          description: _text(p['DESCRIPTION'] ?? ''),
          location: _text(p['LOCATION'] ?? ''),
          start: start,
          end: _date(p['DTEND']) ?? start.add(const Duration(hours: 1)),
          transparent: (p['TRANSP'] ?? '').toUpperCase() == 'TRANSPARENT',
        ));
      } else if (props != null) {
        final colon = line.indexOf(':');
        if (colon <= 0) continue;
        final name = line.substring(0, colon).split(';').first.toUpperCase();
        final value = line.substring(colon + 1);
        props[name] = value;
      }
    }
    return out;
  }

  static List<String> _unfold(String ics) {
    final raw = ics
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final out = <String>[];
    for (final line in raw) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
        out[out.length - 1] += line.substring(1);
      } else {
        out.add(line);
      }
    }
    return out.map((l) => l.trimRight()).toList();
  }

  /// `20261025T090000` (wall clock), `...Z` (UTC) or `20261025` (date only).
  static DateTime? _date(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$')
        .firstMatch(raw.trim());
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    if (m.group(7) == 'Z') {
      return DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6)).toLocal();
    }
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  static String _text(String v) => v
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\', r'\');
}
