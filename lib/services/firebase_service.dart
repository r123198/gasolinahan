import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/station_model.dart';
import '../models/report_model.dart';
import '../models/report_upload.dart';
import 'report_writer.dart';
import 'sync_service.dart';

/// Thrown instead of trying to send while the phone has no network.
class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'OfflineException: no network';
}

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseService() {
    // Every signed-in session needs queued offline reports uploaded; this
    // is constructed at start-up by the auth and dashboard view models.
    SyncService.startAutoSync();
  }

  /// Sending a report gives up after this and queues it offline instead.
  static const _submitTimeout = Duration(seconds: 15);

  /// A sign-up's profile write gives up after this (the account exists).
  static const _profileTimeout = Duration(seconds: 10);

  // ── Auth ──────────────────────────────────────────────

  User? get currentAuthUser => _auth.currentUser;

  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _getOrCreateUserDoc(credential.user!);
  }

  Future<UserModel> signUp(String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;
    final userModel = UserModel(
      id: user.uid,
      name: name,
      email: email.trim(),
      profileImageUrl: '',
      joinDate: DateTime.now().year.toString(),
      subscriptionTier: 'GASOLINAHAN FREE',
      reportsCount: 0,
      points: 0,
      amountSaved: 0.0,
    );

    // The account exists from here on: failing now would strand the user
    // (signing up again says "email already in use"), so fall back to the
    // sign-in path, and failing that to the profile we meant to write; it
    // is created on the next getCurrentUser().
    try {
      await user.updateDisplayName(name);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap())
          .timeout(_profileTimeout);
      return userModel;
    } on Exception catch (e) {
      if (kDebugMode) print('signUp profile setup failed: $e');
      try {
        return await _getOrCreateUserDoc(
          user,
          name: name,
        ).timeout(_profileTimeout);
      } on Exception catch (e) {
        if (kDebugMode) print('signUp profile fallback failed: $e');
        return userModel;
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Adds (or, when negative, takes back) points and records why in
  /// users/{uid}/points_ledger, so every point can be audited later.
  /// Offline, Firestore queues both writes.
  Future<void> awardPoints(
    String uid,
    int points, {
    required String reason,
    required String source,
  }) async {
    if (points == 0) return;
    final user = _firestore.collection('users').doc(uid);
    final batch = _firestore.batch()
      ..set(user, {
        'points': FieldValue.increment(points),
        'lifetimePoints': FieldValue.increment(points),
      }, SetOptions(merge: true))
      ..set(user.collection('points_ledger').doc(), {
        'points': points,
        'reason': reason,
        'source': source,
        'at': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Updates the name on both the auth account and the Firestore profile.
  Future<void> updateName(String userId, String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    await _firestore.collection('users').doc(userId).update({'name': name});
  }

  /// Firebase requires a recent sign-in before a password change, so the
  /// current password is checked first.
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Deletes the account and everything stored for it in the cloud:
  /// fill-ups, points history, price reports, profile photo and profile.
  /// Firebase only deletes recently signed-in accounts, so the password is
  /// checked first. The sign-in account goes last: a failure part-way
  /// leaves the user signed in and able to try again.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    final uid = user.uid;
    // The photo first: if Storage refuses, nothing else is gone yet.
    await _deleteProfileImage(uid);
    final profile = _firestore.collection('users').doc(uid);
    await _deleteAll(profile.collection('fill_ups'));
    await _deleteAll(profile.collection('points_ledger'));
    await _deleteAll(
      _firestore.collection('reports').where('userId', isEqualTo: uid),
    );
    await profile.delete();
    await user.delete();
  }

  /// Under Firestore's 500-writes-per-batch limit.
  static const _deleteBatchSize = 400;

  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    final docs = (await query.get()).docs;
    for (var i = 0; i < docs.length; i += _deleteBatchSize) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(_deleteBatchSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteProfileImage(String uid) async {
    try {
      await _profileImageRef(uid).delete();
    } on FirebaseException catch (e) {
      // Most users never set a photo; a project without Storage has none.
      if (e.code != 'object-not-found' && e.code != 'bucket-not-found') {
        rethrow;
      }
    }
  }

  Reference _profileImageRef(String uid) =>
      FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');

  Future<UserModel> _getOrCreateUserDoc(User authUser, {String? name}) async {
    final doc = await _firestore.collection('users').doc(authUser.uid).get();

    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, authUser.uid);
    }

    final userModel = UserModel(
      id: authUser.uid,
      name: authUser.displayName ?? name ?? 'User',
      email: authUser.email ?? '',
      profileImageUrl: authUser.photoURL ?? '',
      joinDate: DateTime.now().year.toString(),
      subscriptionTier: 'GASOLINAHAN FREE',
      reportsCount: 0,
      points: 0,
      amountSaved: 0.0,
    );

    await _firestore
        .collection('users')
        .doc(authUser.uid)
        .set(userModel.toMap());
    return userModel;
  }

  Future<UserModel?> getCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;
    return _getOrCreateUserDoc(authUser);
  }

  // ── Stations ──────────────────────────────────────────

  Future<List<StationModel>> getNearbyStations() async {
    final snapshot = await _firestore
        .collection('stations')
        .orderBy('lastUpdated', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => StationModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Stations within about [radiusMeters] of ([lat], [lng]), however long
  /// since their last update. Firestore filters the latitude band (a
  /// single-field range, no composite index); longitude is checked here.
  Future<List<StationModel>> getStationsNear(
    double lat,
    double lng, {
    double radiusMeters = 5000,
  }) async {
    final box = GeoBox.around(lat, lng, radiusMeters);
    final snapshot = await _firestore
        .collection('stations')
        .where('latitude', isGreaterThanOrEqualTo: box.minLat)
        .where('latitude', isLessThanOrEqualTo: box.maxLat)
        .get();
    return [
      for (final doc in snapshot.docs)
        if (StationModel.fromMap(doc.data(), doc.id) case final s
            when box.contains(s.latitude, s.longitude))
          s,
    ];
  }

  /// Real-time stream of stations
  Stream<List<StationModel>> stationsStream() {
    return _firestore
        .collection('stations')
        .orderBy('lastUpdated', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StationModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<StationModel?> getStation(String stationId) async {
    final doc = await _firestore.collection('stations').doc(stationId).get();
    if (!doc.exists) return null;
    return StationModel.fromMap(doc.data()!, doc.id);
  }

  // ── Price Reports ─────────────────────────────────────

  // ── User Profile ─────────────────────────────────────

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    final ref = _profileImageRef(userId);
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();
    await _firestore.collection('users').doc(userId).update({
      'profileImageUrl': url,
    });
    return url;
  }

  // ── Favorites ───────────────────────────────────────

  Future<List<String>> getFavoriteStationIds(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final list = data['favoriteStations'];
    if (list is List) return list.cast<String>();
    return [];
  }

  Future<void> addFavoriteStation(String userId, String stationId) async {
    await _firestore.collection('users').doc(userId).update({
      'favoriteStations': FieldValue.arrayUnion([stationId]),
    });
  }

  Future<void> removeFavoriteStation(String userId, String stationId) async {
    await _firestore.collection('users').doc(userId).update({
      'favoriteStations': FieldValue.arrayRemove([stationId]),
    });
  }

  Future<List<StationModel>> getStationsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <StationModel>[];
    // Firestore whereIn limited to 10
    for (var i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await _firestore
          .collection('stations')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      results.addAll(
        snap.docs.map((doc) => StationModel.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  // ── Reports ─────────────────────────────────────────

  Future<List<ReportModel>> getUserReports(
    String userId, {
    int limit = 20,
  }) async {
    // Filter-only query: avoids the userId+timestamp composite index.
    // Sorting and limiting happen client-side; a user's reports are few.
    final snap = await _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .get();
    final reports =
        snap.docs.map((doc) => ReportModel.fromMap(doc.data(), doc.id)).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(reports.take(limit));
  }

  // ── Price Reports ─────────────────────────────────────

  /// A fresh report id, chosen before the first send attempt.
  String newReportId() => ReportWriter(_firestore).newReportId();

  /// Sends [report] (report, station prices, count and points) as one
  /// batch. Throws [OfflineException] without network, or the Firestore /
  /// timeout error; the caller then queues it offline under the same
  /// [ReportUpload.reportId], so a timed-out batch that still lands later
  /// can't be counted twice.
  Future<void> submitPriceReport(ReportUpload report) async {
    if (!await hasNetwork()) throw const OfflineException();
    await ReportWriter(_firestore).write(report).timeout(_submitTimeout);
    notifyReportsUploaded();
  }
}
