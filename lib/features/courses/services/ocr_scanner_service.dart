import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rocis_schedule/features/courses/services/ocr_timetable_parser.dart';

class OcrScannerService {
  /// Scans an image at [filePath] completely on-device using Google ML Kit.
  static Future<OcrTimetableResult> processImageFile(
    String filePath, {
    String? defaultSemester,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // On non-mobile platforms (desktop / web), ML Kit native binary is not bundled.
      // Returns an empty result so caller can offer the text paste fallback.
      return OcrTimetableResult(
        drafts: [],
        rawText: '',
        unparsedLines: ['ML Kit on-device image OCR is available on mobile (Android/iOS).'],
      );
    }

    final inputImage = InputImage.fromFilePath(filePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return OcrTimetableParser.parseText(
        recognizedText.text,
        defaultSemester: defaultSemester,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  /// Parses text directly (e.g. from pasted syllabus, PDF text, or web portal).
  static OcrTimetableResult processRawText(
    String text, {
    String? defaultSemester,
  }) {
    return OcrTimetableParser.parseText(text, defaultSemester: defaultSemester);
  }

  /// Captures a photo via camera or picks an image from the photo gallery.
  static Future<XFile?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
  }
}
