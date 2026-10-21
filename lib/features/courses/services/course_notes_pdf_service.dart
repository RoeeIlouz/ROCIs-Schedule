import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rocis_schedule/shared/models/schedule_models.dart';

enum NotesPaperStyle { ruled, grid }

/// Builds a per-course notebook PDF (cover + blank ruled/grid pages) that
/// Goodnotes, Notability and other PDF-capable notes apps can import.
///
/// The cover is drawn with Flutter's own text engine and embedded as an image,
/// so right-to-left text, Arabic joining and Devanagari shaping render
/// correctly without bundling fonts. The `pdf` package has no complex-script
/// shaping of its own.
class CourseNotesPdfService {
  static const double _pageW = 595.0;
  static const double _pageH = 842.0;
  static const double _coverScale = 2.5;

  /// Weekly meeting lines such as "Mon · Wed  10:00-11:30 · Room 4".
  static List<String> meetingLines(
    List<ScheduleEvent> events,
    String localeCode,
  ) {
    final time = DateFormat.Hm(localeCode);
    final lines = <String>[];
    for (final e in events) {
      if (!e.recurring || e.daysOfWeek.isEmpty) continue;
      final days = ([...e.daysOfWeek]..sort())
          .map(
            // 2024-01-07 is a Sunday, matching daysOfWeek (0 = Sunday).
            (d) => DateFormat.E(localeCode).format(DateTime(2024, 1, 7 + d)),
          )
          .join(' · ');
      final range =
          '${time.format(e.startTime)}-${time.format(e.endTime)}';
      final where = e.location.trim().isEmpty ? '' : ' · ${e.location.trim()}';
      final line = '$days  $range$where';
      if (!lines.contains(line)) lines.add(line);
    }
    return lines;
  }

  static final _unsafeNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

  static String _safeName(String name) {
    final cleaned = name.replaceAll(_unsafeNameChars, '_').trim();
    return cleaned.isEmpty ? 'notes' : cleaned;
  }

  /// A file name safe on every share target, e.g. "Calculus 2.pdf".
  static String fileNameFor(Course course) => '${_safeName(course.name)}.pdf';

  /// The per-course folder name used in the notes folder, e.g. "Calculus 2".
  static String folderNameFor(Course course) => _safeName(course.name);

  Future<Uint8List> buildPdf({
    required Course course,
    required List<ScheduleEvent> events,
    required String instructorLabel,
    required String scheduleLabel,
    required String localeCode,
    required TextDirection textDirection,
    required int pageCount,
    required NotesPaperStyle paper,
  }) async {
    final cover = await _renderCover(
      course: course,
      meetings: meetingLines(events, localeCode),
      instructorLabel: instructorLabel,
      scheduleLabel: scheduleLabel,
      textDirection: textDirection,
    );

    final doc = pw.Document(
      title: course.name,
      author: 'ROCIs Schedule',
      creator: 'ROCIs Schedule',
    );
    final coverImage = pw.MemoryImage(cover);
    const format = PdfPageFormat(_pageW, _pageH);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(coverImage, fit: pw.BoxFit.fill),
      ),
    );
    for (var i = 0; i < pageCount; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.CustomPaint(
            size: const PdfPoint(_pageW, _pageH),
            painter: (canvas, size) => _paintPaper(canvas, size, paper),
          ),
        ),
      );
    }
    return doc.save();
  }

  void _paintPaper(PdfGraphics canvas, PdfPoint size, NotesPaperStyle paper) {
    canvas
      ..setStrokeColor(PdfColor.fromInt(0xFFC9D3E0))
      ..setLineWidth(0.5);
    const margin = 32.0;
    switch (paper) {
      case NotesPaperStyle.ruled:
        const gap = 26.0;
        for (var y = size.y - 64; y > 40; y -= gap) {
          canvas
            ..moveTo(margin, y)
            ..lineTo(size.x - margin, y)
            ..strokePath();
        }
      case NotesPaperStyle.grid:
        const gap = 17.0;
        final cols = ((size.x - 2 * margin) / gap).floor();
        final rows = ((size.y - 2 * margin) / gap).floor();
        final left = (size.x - cols * gap) / 2;
        final bottom = (size.y - rows * gap) / 2;
        for (var c = 0; c <= cols; c++) {
          canvas
            ..moveTo(left + c * gap, bottom)
            ..lineTo(left + c * gap, bottom + rows * gap)
            ..strokePath();
        }
        for (var r = 0; r <= rows; r++) {
          canvas
            ..moveTo(left, bottom + r * gap)
            ..lineTo(left + cols * gap, bottom + r * gap)
            ..strokePath();
        }
    }
  }

  Future<Uint8List> _renderCover({
    required Course course,
    required List<String> meetings,
    required String instructorLabel,
    required String scheduleLabel,
    required TextDirection textDirection,
  }) async {
    const margin = 48.0;
    const contentW = _pageW - 2 * margin;
    const bandH = 280.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_coverScale);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _pageW, _pageH),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _pageW, bandH),
      Paint()..color = course.color,
    );

    final onBand = course.color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    TextPainter paint(String text, TextStyle style, {int maxLines = 1}) {
      return TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(minWidth: contentW, maxWidth: contentW);
    }

    final title = paint(
      course.name,
      TextStyle(
        color: onBand,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      maxLines: 4,
    );
    var titleY = bandH - 36 - title.height;
    if (course.code.trim().isNotEmpty) {
      final code = paint(
        course.code.trim(),
        TextStyle(
          color: onBand.withValues(alpha: 0.8),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      );
      titleY -= code.height + 8;
      code.paint(canvas, Offset(margin, titleY));
      titleY += code.height + 8;
    }
    title.paint(canvas, Offset(margin, titleY));

    var y = bandH + 40;
    void section(String label, List<String> values) {
      if (values.isEmpty) return;
      final head = paint(
        label.toUpperCase(),
        TextStyle(
          color: Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
      head.paint(canvas, Offset(margin, y));
      y += head.height + 8;
      for (final v in values) {
        final p = paint(
          v,
          const TextStyle(color: Colors.black87, fontSize: 20, height: 1.3),
          maxLines: 2,
        );
        p.paint(canvas, Offset(margin, y));
        y += p.height + 4;
      }
      y += 24;
    }

    section(
      instructorLabel,
      course.instructor.trim().isEmpty ? const [] : [course.instructor.trim()],
    );
    section(scheduleLabel, meetings);

    final image = await recorder.endRecording().toImage(
          (_pageW * _coverScale).round(),
          (_pageH * _coverScale).round(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
