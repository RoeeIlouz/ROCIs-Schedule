import 'package:rocis_schedule/shared/models/schedule_models.dart';

/// What [QuickAddParser.parse] understood from one line of text.
class QuickAddParse {
  /// The text left once the recognized course and date words are removed.
  final String title;
  final String? courseId;

  /// End of the due day (23:59), when a date was found.
  final DateTime? dueDate;

  const QuickAddParse({required this.title, this.courseId, this.dueDate});
}

/// Reads a course and a due date out of a line like "calc hw friday" or
/// "תרגיל חדו"א מחר". English and Hebrew date words are understood; a course
/// is matched by its code or by the start of a word in its name.
class QuickAddParser {
  static const _connectors = {
    'due',
    'by',
    'on',
    'until',
    'till',
    'for',
    'עד',
    'ל',
    'ב',
    'ליום',
    'ביום',
  };

  /// Common words never taken for a course name.
  static const _stopWords = {
    'the',
    'and',
    'for',
    'from',
    'with',
    'about',
    'read',
    'page',
    'pages',
    'של',
    'את',
    'על',
    'עם',
    'כל',
    'גם',
    'או',
  };

  static const _enWeekdays = {
    'sunday': 7,
    'sun': 7,
    'monday': 1,
    'mon': 1,
    'tuesday': 2,
    'tue': 2,
    'tues': 2,
    'wednesday': 3,
    'wed': 3,
    'thursday': 4,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'friday': 5,
    'fri': 5,
    'saturday': 6,
    'sat': 6,
  };

  /// Hebrew day names. ראשון and שני also mean "first" and "second", so those
  /// two only count after "יום" or with a ב prefix.
  static const _heWeekdays = {
    'ראשון': 7,
    'שני': 1,
    'שלישי': 2,
    'רביעי': 3,
    'חמישי': 4,
    'שישי': 5,
    'שבת': 6,
  };
  static const _heNeedsPrefix = {'ראשון', 'שני'};

  static final _dateRe = RegExp(r'^(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?$');
  static final _intRe = RegExp(r'^\d{1,3}$');

  /// [monthFirst] reads 3/4 as March 4 (US); otherwise as 3 April.
  static QuickAddParse parse(
    String text,
    List<Course> courses,
    DateTime now, {
    bool monthFirst = false,
  }) {
    final tokens = text.trim().split(RegExp(r'\s+'))
      ..removeWhere((t) => t.isEmpty);
    final used = List<bool>.filled(tokens.length, false);
    final today = DateTime(now.year, now.month, now.day);

    DateTime? day;
    var dateStart = -1;

    String norm(int i) => _normalize(tokens[i]);

    // Date: the first phrase that reads as one wins.
    for (var i = 0; i < tokens.length && day == null; i++) {
      final t = norm(i);
      final next = i + 1 < tokens.length ? norm(i + 1) : '';
      final next2 = i + 2 < tokens.length ? norm(i + 2) : '';
      var len = 0;
      DateTime? found;

      int? weeks(String w) =>
          const {'week': 1, 'weeks': 1, 'שבוע': 1, 'שבועות': 1}[w];
      int? days(String w) =>
          const {'day': 1, 'days': 1, 'יום': 1, 'ימים': 1}[w];

      if (t == 'today' || t == 'tonight' || t == 'היום') {
        found = today;
        len = 1;
      } else if (t == 'tomorrow' || t == 'tmrw' || t == 'tmr' || t == 'מחר') {
        found = today.add(const Duration(days: 1));
        len = 1;
      } else if (t == 'מחרתיים') {
        found = today.add(const Duration(days: 2));
        len = 1;
      } else if ((t == 'next' && next == 'week') ||
          (t == 'שבוע' && next == 'הבא') ||
          (t == 'בשבוע' && next == 'הבא')) {
        found = today.add(const Duration(days: 7));
        len = 2;
      } else if ((t == 'in' || t == 'בעוד') && _intRe.hasMatch(next)) {
        final n = int.parse(next);
        if (days(next2) != null) {
          found = today.add(Duration(days: n));
          len = 3;
        } else if (weeks(next2) != null) {
          found = today.add(Duration(days: 7 * n));
          len = 3;
        }
      } else if (t == 'בעוד' && next == 'יומיים') {
        found = today.add(const Duration(days: 2));
        len = 2;
      } else if (t == 'בעוד' && weeks(next) != null) {
        found = today.add(const Duration(days: 7));
        len = 2;
      } else if (t == 'בעוד' && next == 'שבועיים') {
        found = today.add(const Duration(days: 14));
        len = 2;
      } else if (_intRe.hasMatch(t) && days(next) != null) {
        found = today.add(Duration(days: int.parse(t)));
        len = 2;
      } else if (t == 'next' && _enWeekdays[next] != null) {
        found = _nextWeekday(today, _enWeekdays[next]!);
        len = 2;
      } else if (_enWeekdays[t] != null) {
        found = _nextWeekday(today, _enWeekdays[t]!);
        len = 1;
      } else if ((t == 'יום' || t == 'ביום' || t == 'ליום') &&
          _heWeekdays[next] != null) {
        found = _nextWeekday(today, _heWeekdays[next]!);
        len = 2;
      } else if (_heWeekdays[t] != null && !_heNeedsPrefix.contains(t)) {
        found = _nextWeekday(today, _heWeekdays[t]!);
        len = 1;
      } else if (t.startsWith('ב') && _heWeekdays[t.substring(1)] != null) {
        found = _nextWeekday(today, _heWeekdays[t.substring(1)]!);
        len = 1;
      } else if (_dateRe.firstMatch(tokens[i].trim()) case final m?) {
        found = _explicitDate(m, today, monthFirst);
        len = found == null ? 0 : 1;
      }

      if (found != null && len > 0) {
        day = found;
        dateStart = i;
        for (var k = i; k < i + len; k++) {
          used[k] = true;
        }
      }
    }
    // "due friday", "עד יום חמישי": drop the word that led into the date.
    if (dateStart > 0 &&
        !used[dateStart - 1] &&
        _connectors.contains(norm(dateStart - 1))) {
      used[dateStart - 1] = true;
    }

    // Course: a token that points at exactly one course.
    String? courseId;
    var courseToken = -1;
    for (var i = 0; i < tokens.length && courseId == null; i++) {
      if (used[i]) continue;
      final t = norm(i);
      if (t.length < 2 || _stopWords.contains(t)) continue;
      final match = _matchCourse(t, courses);
      if (match != null) {
        courseId = match;
        courseToken = i;
      }
    }

    final rest = <String>[
      for (var i = 0; i < tokens.length; i++)
        if (!used[i] && i != courseToken) tokens[i],
    ];
    // Keep the course word as the title rather than leave it empty.
    final title = rest.isEmpty && courseToken >= 0
        ? tokens[courseToken]
        : rest.join(' ');

    return QuickAddParse(
      title: title,
      courseId: courseId,
      dueDate: day == null
          ? null
          : DateTime(day.year, day.month, day.day, 23, 59),
    );
  }

  /// Lowercase, without punctuation or Hebrew quote marks (חדו"א = חדוא).
  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'''["'״׳`.,!?:;()\[\]-]'''), '');

  static String? _matchCourse(String token, List<Course> courses) {
    final candidates = <String>{token};
    // Hebrew one-letter prefixes: בחדוא, לחדוא, והחדוא...
    var t = token;
    while (t.length > 3 && 'בלהוכמש'.contains(t[0])) {
      t = t.substring(1);
      candidates.add(t);
    }

    final hits = <String>{};
    for (final c in courses) {
      final code = _normalize(c.code).replaceAll(' ', '');
      final words = c.name
          .split(RegExp(r'\s+'))
          .map(_normalize)
          .where((w) => w.isNotEmpty);
      for (final cand in candidates) {
        if (code.isNotEmpty && cand == code) hits.add(c.id);
        if (cand.length >= 3 && words.any((w) => w.startsWith(cand))) {
          hits.add(c.id);
        }
      }
    }
    return hits.length == 1 ? hits.first : null;
  }

  /// The next [weekday] (DateTime.monday..sunday) after today; today's own
  /// name means a week from today.
  static DateTime _nextWeekday(DateTime today, int weekday) {
    var diff = (weekday - today.weekday) % 7;
    if (diff == 0) diff = 7;
    return today.add(Duration(days: diff));
  }

  static DateTime? _explicitDate(
    RegExpMatch m,
    DateTime today,
    bool monthFirst,
  ) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final dayN = monthFirst ? b : a;
    final month = monthFirst ? a : b;
    if (month < 1 || month > 12 || dayN < 1 || dayN > 31) return null;
    var year = today.year;
    if (m.group(3) case final y?) {
      year = int.parse(y);
      if (year < 100) year += 2000;
    }
    var date = DateTime(year, month, dayN);
    if (date.month != month) return null; // 31/2
    if (m.group(3) == null && date.isBefore(today)) {
      date = DateTime(year + 1, month, dayN);
    }
    return date;
  }
}
