import 'fill_up_model.dart';

/// What to change on each side to bring this device and the cloud together.
class FillUpSyncPlan {
  /// Logged on another device: add here (no photos — those stay on the
  /// device that took them).
  final List<FillUp> insertLocal;

  /// Edited more recently elsewhere: replace the local copy (same local id,
  /// local photos kept).
  final List<FillUp> updateLocal;

  /// Deleted on another device.
  final List<FillUp> deleteLocal;

  /// Never synced, or edited here more recently: send to the cloud.
  final List<FillUp> upload;

  const FillUpSyncPlan({
    this.insertLocal = const [],
    this.updateLocal = const [],
    this.deleteLocal = const [],
    this.upload = const [],
  });

  bool get isEmpty =>
      insertLocal.isEmpty &&
      updateLocal.isEmpty &&
      deleteLocal.isEmpty &&
      upload.isEmpty;
}

/// Compares this device's fill-ups with the cloud copy. [remote] must be a
/// complete server read (Firestore folds this device's queued writes into
/// it), so a synced row missing from it was deleted elsewhere.
FillUpSyncPlan planFillUpSync({
  required List<FillUp> local,
  required List<FillUp> remote,
}) {
  final remoteById = {for (final r in remote) r.remoteId!: r};
  final localRemoteIds = <String>{};
  final updateLocal = <FillUp>[];
  final deleteLocal = <FillUp>[];
  final upload = <FillUp>[];

  for (final l in local) {
    final id = l.remoteId;
    if (id == null) {
      upload.add(l);
      continue;
    }
    localRemoteIds.add(id);
    final r = remoteById[id];
    if (r == null) {
      deleteLocal.add(l);
    } else if (_isNewer(r.updatedAt, l.updatedAt)) {
      updateLocal.add(
        r.copyWith(id: l.id, photoPaths: l.photoPaths, ownerUid: l.ownerUid),
      );
    } else if (_isNewer(l.updatedAt, r.updatedAt)) {
      upload.add(l);
    }
  }

  return FillUpSyncPlan(
    insertLocal: [
      for (final r in remote)
        if (!localRemoteIds.contains(r.remoteId)) r,
    ],
    updateLocal: updateLocal,
    deleteLocal: deleteLocal,
    upload: upload,
  );
}

bool _isNewer(DateTime? a, DateTime? b) =>
    a != null && (b == null || a.isAfter(b));
