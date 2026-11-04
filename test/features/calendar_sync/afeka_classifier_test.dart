import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/afeka_classifier.dart';

FeedEntry entry(
  String summary, {
  String description = '',
  bool transparent = false,
}) => FeedEntry(
  uid: 'u',
  summary: summary,
  description: description,
  start: DateTime(2026, 10, 25, 9),
  end: DateTime(2026, 10, 25, 10),
  transparent: transparent,
);

void main() {
  test('strips lecturer after the course name for each title prefix', () {
    for (final title in ['ד"ר', 'מר', "גב'", "פרופ'"]) {
      final c = AfekaClassifier.classify(
        entry('אלגברה ליניארית $title לוי דנה'),
      );
      expect(c.courseName, 'אלגברה ליניארית');
      expect(c.lecturer, '$title לוי דנה');
    }
  });

  test('keeps a course name that contains digits', () {
    final c = AfekaClassifier.classify(
      entry('חשבון דיפרנציאלי אינטגרלי1 ד"ר גבל מיקה'),
    );
    expect(c.courseName, 'חשבון דיפרנציאלי אינטגרלי1');
  });

  test('unmatched title keeps whole string as course name', () {
    final c = AfekaClassifier.classify(entry('קורס בלי מרצה'));
    expect(c.courseName, 'קורס בלי מרצה');
    expect(c.lecturer, '');
  });

  test('detects practice and lecture from the description', () {
    expect(
      AfekaClassifier.classify(
        entry(
          'א מר ב',
          description: 'סוג מפגש: תרגול חדר לימוד: (מתקיים) קורס',
        ),
      ).kind,
      EntryKind.practice,
    );
    expect(
      AfekaClassifier.classify(
        entry('א מר ב', description: 'סוג מפגש: סופי-הרצאה+תרגול חדר לימוד'),
      ).kind,
      EntryKind.lecture,
    );
  });

  test('cancelled marker is detected and removed from the names', () {
    final c = AfekaClassifier.classify(
      entry('פיזיקה-מכניקה מר אבי גולן ** השיעור מבוטל **'),
    );
    expect(c.cancelled, isTrue);
    expect(c.courseName, 'פיזיקה-מכניקה');
    expect(c.lecturer, 'מר אבי גולן');
  });

  test('exam registration is read from the description', () {
    final yes = AfekaClassifier.classify(
      entry(
        'מבחן מועד 1 בחינה אלגברה ליניארית',
        description: 'מבחן מועד 1 בחינה.חדר לימוד : .רשום למבחן',
      ),
    );
    final no = AfekaClassifier.classify(
      entry(
        'מבחן מועד 2 בחינה אלגברה ליניארית',
        description: 'מבחן מועד 2 בחינה.חדר לימוד : .לא רשום למבחן',
      ),
    );
    expect(yes.kind, EntryKind.exam);
    expect(yes.registered, isTrue);
    expect(yes.courseName, 'אלגברה ליניארית');
    expect(no.registered, isFalse);
  });

  test('transparent entries are skipped', () {
    expect(
      AfekaClassifier.classify(entry('חנוכה', transparent: true)).kind,
      EntryKind.skip,
    );
  });

  test('normalizeName removes bidi marks and collapses whitespace', () {
    expect(
      AfekaClassifier.normalizeName('\u200Fאלגברה\u202B   ליניארית \u200E'),
      'אלגברה ליניארית',
    );
  });
}
