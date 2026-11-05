import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:uuid/uuid.dart';

/// Largest stored attachment. A Firestore document is capped at 1 MiB, so this
/// leaves room for the metadata fields and the field overhead.
const int kMaxAttachmentBytes = 700 * 1024;

/// Thrown when a file can't be made small enough to store.
class AttachmentTooLargeException implements Exception {
  final String fileName;
  final int originalBytes;
  final int bestBytes;

  const AttachmentTooLargeException(
    this.fileName,
    this.originalBytes,
    this.bestBytes,
  );

  @override
  String toString() =>
      '$fileName is too large even after compression '
      '(${(bestBytes / 1024).round()} KB, limit '
      '${kMaxAttachmentBytes ~/ 1024} KB)';
}

/// An attachment ready to store: its metadata plus the (compressed) bytes.
class PreparedAttachment {
  final AssignmentAttachment meta;
  final Uint8List data;

  const PreparedAttachment(this.meta, this.data);
}

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

const _mimeByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'zip': 'application/zip',
};

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String mimeForName(String name) =>
    _mimeByExtension[_extensionOf(name)] ?? 'application/octet-stream';

/// Compresses [bytes] to fit [kMaxAttachmentBytes].
///
/// Images that already fit are kept byte-for-byte. Larger ones are re-encoded
/// as JPEG at the largest size and highest quality that still fits, so the
/// 700 KB budget is spent on detail rather than wasted. Anything else is
/// gzipped, which helps text and office files but not already-packed formats
/// like PDF or ZIP; if it still doesn't fit, [AttachmentTooLargeException].
Future<PreparedAttachment> prepareAttachment({
  required String name,
  required Uint8List bytes,
}) async {
  final cleanName = name.trim().isEmpty ? 'file' : name.trim();
  final id = const Uuid().v4();
  final isImage = _imageExtensions.contains(_extensionOf(cleanName));

  if (isImage) {
    if (bytes.length <= kMaxAttachmentBytes) {
      return PreparedAttachment(
        AssignmentAttachment(
          id: id,
          name: cleanName,
          mime: mimeForName(cleanName),
          size: bytes.length,
        ),
        bytes,
      );
    }
    final jpeg = await compute(_compressImage, bytes);
    if (jpeg != null) {
      if (jpeg.length > kMaxAttachmentBytes) {
        throw AttachmentTooLargeException(cleanName, bytes.length, jpeg.length);
      }
      return PreparedAttachment(
        AssignmentAttachment(
          id: id,
          name: _withJpegExtension(cleanName),
          mime: 'image/jpeg',
          size: jpeg.length,
        ),
        jpeg,
      );
    }
    // Undecodable "image" (e.g. HEIC): fall through and treat it as a file.
  }

  final zipped = await compute(_gzip, bytes);
  final useZip = zipped.length < bytes.length;
  final stored = useZip ? zipped : bytes;
  if (stored.length > kMaxAttachmentBytes) {
    throw AttachmentTooLargeException(cleanName, bytes.length, stored.length);
  }
  return PreparedAttachment(
    AssignmentAttachment(
      id: id,
      name: cleanName,
      mime: mimeForName(cleanName),
      size: stored.length,
      gzipped: useZip,
    ),
    stored,
  );
}

/// Original bytes of an attachment, inflating it if it was stored gzipped.
Uint8List restoreAttachmentBytes(AssignmentAttachment meta, Uint8List stored) {
  if (!meta.gzipped) return stored;
  return GZipDecoder().decodeBytes(stored);
}

String _withJpegExtension(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot <= 0 ? name : name.substring(0, dot);
  return '$base.jpg';
}

Uint8List _gzip(Uint8List bytes) => GZipEncoder().encodeBytes(bytes, level: 9);

/// Longest-side sizes to try, biggest first.
const _sideLadder = [2560, 2048, 1600, 1280, 1024, 800, 640];

const _minQuality = 40;
const _maxQuality = 92;

/// A quality at or above this at some size is "good enough" to stop shrinking.
const _goodQuality = 72;

/// Returns JPEG bytes that fit the budget, the smallest attempt if none do,
/// or null when [bytes] isn't a decodable image.
Uint8List? _compressImage(Uint8List bytes) {
  var decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  decoded = img.bakeOrientation(decoded);

  // JPEG has no alpha; flatten onto white so transparency doesn't go black.
  if (decoded.hasAlpha) {
    final flat = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    decoded = flat;
  }

  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;

  Uint8List? bestFit; // highest-quality encoding that fits
  Uint8List? smallest; // fallback to report when nothing fits

  for (final side in _sideLadder) {
    final candidate = longest > side
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? side : null,
            height: decoded.height > decoded.width ? side : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    // Binary search the highest JPEG quality that fits at this size.
    var lo = _minQuality;
    var hi = _maxQuality;
    Uint8List? fitAtSize;
    int fitQuality = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final encoded = img.encodeJpg(candidate, quality: mid);
      if (smallest == null || encoded.length < smallest.length) {
        smallest = encoded;
      }
      if (encoded.length <= kMaxAttachmentBytes) {
        fitAtSize = encoded;
        fitQuality = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    if (fitAtSize != null) {
      bestFit = fitAtSize;
      if (fitQuality >= _goodQuality) return fitAtSize;
    }
  }

  return bestFit ?? smallest;
}
