import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fill_up_model.dart';

/// Cloud copy of a user's fill-ups, so they follow the user across phones.
abstract interface class FillUpRemote {
  /// A fresh document id, available offline.
  String newId(String uid);

  /// Every fill-up from the server (with this device's queued writes
  /// folded in). Throws when the server can't be reached.
  Future<List<FillUp>> fetchAll(String uid);

  /// Creates or replaces [fillUp] (its [FillUp.remoteId] must be set).
  /// Completes when the server has it; offline, Firestore keeps the write
  /// queued (even across restarts) and sends it later.
  Future<void> save(String uid, FillUp fillUp);

  Future<void> delete(String uid, String remoteId);
}

/// [FillUpRemote] backed by Firestore at users/{uid}/fill_ups/{remoteId}.
class FirestoreFillUpRemote implements FillUpRemote {
  final FirebaseFirestore _db;

  FirestoreFillUpRemote([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('fill_ups');

  @override
  String newId(String uid) => _col(uid).doc().id;

  @override
  Future<List<FillUp>> fetchAll(String uid) async {
    final snap = await _col(uid).get(const GetOptions(source: Source.server));
    return [for (final d in snap.docs) FillUp.fromRemote(d.data(), d.id)];
  }

  @override
  Future<void> save(String uid, FillUp fillUp) =>
      _col(uid).doc(fillUp.remoteId).set(fillUp.toRemoteMap());

  @override
  Future<void> delete(String uid, String remoteId) =>
      _col(uid).doc(remoteId).delete();
}
