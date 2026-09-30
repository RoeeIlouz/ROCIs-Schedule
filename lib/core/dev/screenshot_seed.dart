import 'package:flutter/material.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Store-screenshot demo data. Only compiled in with
/// `--dart-define=SCREENSHOT_SEED=true` (a compile-time constant, so release
/// builds never touch user data). Fills an empty local database only, in the
/// app language saved under the `locale` preference (English otherwise).
class ScreenshotSeed {
  ScreenshotSeed._();

  static const enabled = bool.fromEnvironment('SCREENSHOT_SEED');

  // (id, code, color, credits, grade); names and instructors come from _text.
  static const _courses = [
    ('c_linalg', 'MATH 201', 0xFF0EA5E9, 4.0, 91.0),
    ('c_ds', 'CS 210', 0xFF10B981, 5.0, 88.0),
    ('c_psych', 'PSY 101', 0xFFF59E0B, 3.0, 94.0),
    ('c_econ', 'ECON 110', 0xFFF43F5E, 3.0, null),
    ('c_write', 'ENG 120', 0xFF14B8A6, 2.0, null),
  ];

  // (courseId, title key, type, weekdays 0=Sun, start h, start m, end h, end m, room index)
  static const _classes = [
    ('c_linalg', 'lecture', EventType.classType, [1, 3], 9, 0, 10, 30, 0),
    ('c_ds', 'lecture', EventType.classType, [1, 4], 11, 0, 12, 30, 1),
    ('c_econ', 'lecture', EventType.classType, [1, 3], 14, 0, 15, 30, 2),
    ('c_ds', 'lab', EventType.lab, [2], 14, 0, 16, 0, 3),
    ('c_psych', 'lecture', EventType.classType, [2, 4], 9, 30, 11, 0, 4),
    ('c_write', 'seminar', EventType.classType, [0, 2], 12, 0, 13, 30, 5),
    ('c_linalg', 'study', EventType.study, [0], 15, 0, 16, 30, 6),
  ];

  // (courseId, days from today, hour, room index)
  static const _exams = [
    ('c_linalg', 12, 9, 7),
    ('c_ds', 19, 13, 8),
    ('c_econ', 33, 10, 9),
  ];

  // (courseId, title index, days from today, priority, done)
  static const _assignments = [
    ('c_ds', 0, 2, AssignmentPriority.high, false),
    ('c_linalg', 1, 4, AssignmentPriority.medium, false),
    ('c_write', 2, 6, AssignmentPriority.medium, false),
    ('c_psych', 3, 1, AssignmentPriority.low, false),
    ('c_econ', 4, -1, AssignmentPriority.medium, true),
  ];

  static const _text = <String, Map<String, dynamic>>{
    'en': {
      'semester': 'Fall 2026',
      'names': ['Linear Algebra', 'Data Structures', 'Intro to Psychology', 'Microeconomics', 'Academic Writing'],
      'instructors': ['Dr. Sarah Levin', 'Prof. Daniel Cohen', 'Dr. Maya Rosen', 'Dr. Adam Weiss', 'Ms. Noa Katz'],
      'lecture': 'Lecture', 'lab': 'Lab session', 'seminar': 'Seminar', 'study': 'Study group', 'exam': 'Final exam',
      'rooms': ['Science Hall 204', 'CS Building 1.12', 'Social Sciences 105', 'Computer Lab B', 'Auditorium 3',
        'Humanities 21', 'Library, 2nd floor', 'Exam Center A', 'CS Building 0.01', 'Exam Center B'],
      'assignments': ['Binary search tree project', 'Problem set 4: eigenvalues', 'Essay outline draft',
        'Reading: chapters 5-6', 'Supply and demand worksheet'],
    },
    'he': {
      'semester': 'סמסטר א׳ 2026',
      'names': ['אלגברה לינארית', 'מבני נתונים', 'מבוא לפסיכולוגיה', 'מיקרו-כלכלה', 'כתיבה אקדמית'],
      'instructors': ['ד״ר שרה לוין', 'פרופ׳ דניאל כהן', 'ד״ר מאיה רוזן', 'ד״ר אדם וייס', 'גב׳ נועה כץ'],
      'lecture': 'הרצאה', 'lab': 'מעבדה', 'seminar': 'סמינר', 'study': 'קבוצת לימוד', 'exam': 'מבחן סופי',
      'rooms': ['בניין מדעים 204', 'בניין מדמ״ח 1.12', 'מדעי החברה 105', 'מעבדת מחשבים ב׳', 'אודיטוריום 3',
        'מדעי הרוח 21', 'ספרייה, קומה 2', 'מרכז בחינות א׳', 'בניין מדמ״ח 0.01', 'מרכז בחינות ב׳'],
      'assignments': ['פרויקט עץ חיפוש בינארי', 'תרגיל 4: ערכים עצמיים', 'טיוטת שלד לחיבור',
        'קריאה: פרקים 5-6', 'דף עבודה: היצע וביקוש'],
    },
    'ar': {
      'semester': 'خريف 2026',
      'names': ['الجبر الخطي', 'هياكل البيانات', 'مقدمة في علم النفس', 'الاقتصاد الجزئي', 'الكتابة الأكاديمية'],
      'instructors': ['د. سارة ليفين', 'أ.د. دانيال كوهين', 'د. مايا روزن', 'د. آدم فايس', 'أ. نوعا كاتس'],
      'lecture': 'محاضرة', 'lab': 'جلسة مختبر', 'seminar': 'حلقة نقاش', 'study': 'مجموعة دراسة', 'exam': 'الامتحان النهائي',
      'rooms': ['مبنى العلوم 204', 'مبنى الحاسوب 1.12', 'العلوم الاجتماعية 105', 'مختبر الحاسوب ب', 'القاعة 3',
        'العلوم الإنسانية 21', 'المكتبة، الطابق 2', 'مركز الامتحانات أ', 'مبنى الحاسوب 0.01', 'مركز الامتحانات ب'],
      'assignments': ['مشروع شجرة البحث الثنائية', 'تمارين 4: القيم الذاتية', 'مسودة مخطط المقال',
        'قراءة: الفصلان 5-6', 'ورقة عمل العرض والطلب'],
    },
    'es': {
      'semester': 'Otoño 2026',
      'names': ['Álgebra lineal', 'Estructuras de datos', 'Introducción a la psicología', 'Microeconomía', 'Redacción académica'],
      'instructors': ['Dra. Sara Levin', 'Prof. Daniel Cohen', 'Dra. Maya Rosen', 'Dr. Adam Weiss', 'Sra. Noa Katz'],
      'lecture': 'Clase teórica', 'lab': 'Laboratorio', 'seminar': 'Seminario', 'study': 'Grupo de estudio', 'exam': 'Examen final',
      'rooms': ['Edificio de Ciencias 204', 'Informática 1.12', 'Ciencias Sociales 105', 'Laboratorio B', 'Auditorio 3',
        'Humanidades 21', 'Biblioteca, 2.ª planta', 'Centro de exámenes A', 'Informática 0.01', 'Centro de exámenes B'],
      'assignments': ['Proyecto de árbol binario de búsqueda', 'Ejercicios 4: autovalores', 'Borrador del esquema del ensayo',
        'Lectura: capítulos 5-6', 'Hoja de oferta y demanda'],
    },
    'de': {
      'semester': 'Wintersemester 2026',
      'names': ['Lineare Algebra', 'Datenstrukturen', 'Einführung in die Psychologie', 'Mikroökonomie', 'Wissenschaftliches Schreiben'],
      'instructors': ['Dr. Sarah Levin', 'Prof. Daniel Cohen', 'Dr. Maya Rosen', 'Dr. Adam Weiss', 'Noa Katz'],
      'lecture': 'Vorlesung', 'lab': 'Praktikum', 'seminar': 'Seminar', 'study': 'Lerngruppe', 'exam': 'Abschlussprüfung',
      'rooms': ['Naturwissenschaften 204', 'Informatik 1.12', 'Sozialwissenschaften 105', 'Rechnerraum B', 'Hörsaal 3',
        'Geisteswissenschaften 21', 'Bibliothek, 2. OG', 'Prüfungszentrum A', 'Informatik 0.01', 'Prüfungszentrum B'],
      'assignments': ['Projekt: binärer Suchbaum', 'Übungsblatt 4: Eigenwerte', 'Gliederung für den Essay',
        'Lektüre: Kapitel 5-6', 'Arbeitsblatt Angebot und Nachfrage'],
    },
    'fr': {
      'semester': 'Automne 2026',
      'names': ['Algèbre linéaire', 'Structures de données', 'Introduction à la psychologie', 'Microéconomie', 'Rédaction universitaire'],
      'instructors': ['Dr Sarah Levin', 'Pr Daniel Cohen', 'Dr Maya Rosen', 'Dr Adam Weiss', 'Mme Noa Katz'],
      'lecture': 'Cours magistral', 'lab': 'Travaux pratiques', 'seminar': 'Séminaire', 'study': 'Groupe de travail', 'exam': 'Examen final',
      'rooms': ['Bâtiment Sciences 204', 'Informatique 1.12', 'Sciences sociales 105', 'Salle info B', 'Amphi 3',
        'Lettres 21', 'Bibliothèque, 2e étage', "Centre d'examen A", 'Informatique 0.01', "Centre d'examen B"],
      'assignments': ['Projet arbre binaire de recherche', 'TD 4 : valeurs propres', 'Plan de la dissertation',
        'Lecture : chapitres 5-6', "Fiche offre et demande"],
    },
    'sv': {
      'semester': 'Hösttermin 2026',
      'names': ['Linjär algebra', 'Datastrukturer', 'Introduktion till psykologi', 'Mikroekonomi', 'Akademiskt skrivande'],
      'instructors': ['Dr. Sarah Levin', 'Prof. Daniel Cohen', 'Dr. Maya Rosen', 'Dr. Adam Weiss', 'Noa Katz'],
      'lecture': 'Föreläsning', 'lab': 'Labb', 'seminar': 'Seminarium', 'study': 'Studiegrupp', 'exam': 'Slutexamen',
      'rooms': ['Naturvetarhuset 204', 'Datavetenskap 1.12', 'Samhällsvetenskap 105', 'Datorsal B', 'Aula 3',
        'Humanisthuset 21', 'Biblioteket, plan 2', 'Tentamenssal A', 'Datavetenskap 0.01', 'Tentamenssal B'],
      'assignments': ['Projekt: binärt sökträd', 'Övning 4: egenvärden', 'Disposition för uppsatsen',
        'Läsning: kapitel 5-6', 'Utbud och efterfrågan, övning'],
    },
    'hi': {
      'semester': 'सेमेस्टर 1, 2026',
      'names': ['रैखिक बीजगणित', 'डेटा संरचनाएँ', 'मनोविज्ञान का परिचय', 'व्यष्टि अर्थशास्त्र', 'अकादमिक लेखन'],
      'instructors': ['डॉ. सारा लेविन', 'प्रो. डैनियल कोहेन', 'डॉ. माया रोज़ेन', 'डॉ. एडम वाइस', 'सुश्री नोआ कात्ज़'],
      'lecture': 'व्याख्यान', 'lab': 'लैब सत्र', 'seminar': 'संगोष्ठी', 'study': 'अध्ययन समूह', 'exam': 'अंतिम परीक्षा',
      'rooms': ['विज्ञान भवन 204', 'सीएस भवन 1.12', 'सामाजिक विज्ञान 105', 'कंप्यूटर लैब B', 'सभागार 3',
        'मानविकी 21', 'पुस्तकालय, दूसरी मंज़िल', 'परीक्षा केंद्र A', 'सीएस भवन 0.01', 'परीक्षा केंद्र B'],
      'assignments': ['बाइनरी सर्च ट्री प्रोजेक्ट', 'प्रश्नावली 4: आइगेन मान', 'निबंध की रूपरेखा',
        'पठन: अध्याय 5-6', 'माँग और आपूर्ति वर्कशीट'],
    },
  };

  static Future<void> apply(LocalDbService db) async {
    if ((await db.getCourses()).isNotEmpty) return;
    final lang = (await SharedPreferences.getInstance()).getString('locale');
    final t = _text[lang] ?? _text['en']!;
    final names = t['names'] as List<String>;
    final instructors = t['instructors'] as List<String>;
    final rooms = t['rooms'] as List<String>;
    final assignments = t['assignments'] as List<String>;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await db.insertSemester(Semester(
      id: 'semester_1',
      name: t['semester'] as String,
      startDate: today.subtract(const Duration(days: 21)),
      endDate: today.add(const Duration(days: 90)),
    ));
    for (final (n, c) in _courses.indexed) {
      await db.insertCourse(Course(
        id: c.$1,
        name: names[n],
        code: c.$2,
        instructor: instructors[n],
        color: Color(c.$3),
        credits: c.$4,
        grade: c.$5,
      ));
    }
    var i = 0;
    for (final e in _classes) {
      await db.insertEvent(ScheduleEvent(
        id: 'seed_class_${i++}',
        title: t[e.$2] as String,
        courseId: e.$1,
        type: e.$3,
        startTime: today.add(Duration(hours: e.$5, minutes: e.$6)),
        endTime: today.add(Duration(hours: e.$7, minutes: e.$8)),
        location: rooms[e.$9],
        daysOfWeek: e.$4,
        recurring: true,
      ));
    }
    for (final e in _exams) {
      final start = today.add(Duration(days: e.$2, hours: e.$3));
      await db.insertEvent(ScheduleEvent(
        id: 'seed_exam_${i++}',
        title: t['exam'] as String,
        courseId: e.$1,
        type: EventType.exam,
        startTime: start,
        endTime: start.add(const Duration(hours: 3)),
        location: rooms[e.$4],
      ));
    }
    for (final a in _assignments) {
      await db.insertAssignment(Assignment(
        id: 'seed_asg_${i++}',
        courseId: a.$1,
        title: assignments[a.$2],
        dueDate: today.add(Duration(days: a.$3, hours: 23, minutes: 59)),
        priority: a.$4,
        isCompleted: a.$5,
      ));
    }
  }
}
