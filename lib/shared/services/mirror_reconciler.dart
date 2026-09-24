import 'dart:convert';

/// What to do after comparing a cloud snapshot with the local cache.
class MirrorPlan<T> {
  /// Cloud records that are new or changed locally.
  final List<T> upsertLocal;

  /// Local records deleted on another device.
  final List<String> deleteLocal;

  /// Local records that never reached the cloud.
  final List<T> uploadToCloud;

  /// Ids the server has confirmed, or null when the snapshot came from the
  /// offline cache (which proves nothing about deletions).
  final Set<String>? confirmedIds;

  const MirrorPlan({
    required this.upsertLocal,
    required this.deleteLocal,
    required this.uploadToCloud,
    required this.confirmedIds,
  });

  bool get changesLocal => upsertLocal.isNotEmpty || deleteLocal.isNotEmpty;
}

/// Plans how to mirror a cloud collection into the local cache.
///
/// The cloud is the source of truth. A local record missing from the cloud is
/// either deleted elsewhere (its id was previously confirmed by the server) or
/// was created here and never uploaded (never confirmed) — deleting the first
/// and uploading the second avoids both data loss and resurrecting deletions.
MirrorPlan<T> planMirror<T>({
  required List<T> remote,
  required List<T> local,
  required String Function(T) idOf,
  required Map<String, dynamic> Function(T) toMap,
  required Set<String> confirmedIds,
  required bool fromCache,
}) {
  final localById = {for (final item in local) idOf(item): item};
  final remoteIds = <String>{};
  final upserts = <T>[];

  for (final item in remote) {
    final id = idOf(item);
    remoteIds.add(id);
    final existing = localById[id];
    if (existing == null || !sameRecord(toMap(existing), toMap(item))) {
      upserts.add(item);
    }
  }

  final deletes = <String>[];
  final uploads = <T>[];
  if (!fromCache) {
    for (final entry in localById.entries) {
      if (remoteIds.contains(entry.key)) continue;
      if (confirmedIds.contains(entry.key)) {
        deletes.add(entry.key);
      } else {
        uploads.add(entry.value);
      }
    }
  }

  return MirrorPlan(
    upsertLocal: upserts,
    deleteLocal: deletes,
    uploadToCloud: uploads,
    confirmedIds: fromCache ? null : remoteIds,
  );
}

/// Records are equal when their serialized forms match (all model maps hold
/// JSON primitives).
bool sameRecord(Map<String, dynamic> a, Map<String, dynamic> b) =>
    jsonEncode(a) == jsonEncode(b);
