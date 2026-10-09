import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/station_model.dart';
import '../models/report_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    await user.updateDisplayName(name);

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

    await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
    return userModel;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserModel> _getOrCreateUserDoc(User authUser) async {
    final doc = await _firestore.collection('users').doc(authUser.uid).get();

    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, authUser.uid);
    }

    final userModel = UserModel(
      id: authUser.uid,
      name: authUser.displayName ?? 'User',
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

  /// Real-time stream of stations
  Stream<List<StationModel>> stationsStream() {
    return _firestore
        .collection('stations')
        .orderBy('lastUpdated', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<StationModel?> getStation(String stationId) async {
    final doc = await _firestore.collection('stations').doc(stationId).get();
    if (!doc.exists) return null;
    return StationModel.fromMap(doc.data()!, doc.id);
  }

  // ── Price Reports ─────────────────────────────────────

  // ── User Profile ─────────────────────────────────────

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$userId.jpg');
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

  Future<List<ReportModel>> getUserReports(String userId, {int limit = 20}) async {
    // Filter-only query: avoids the userId+timestamp composite index.
    // Sorting and limiting happen client-side; a user's reports are few.
    final snap = await _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .get();
    final reports = snap.docs
        .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(reports.take(limit));
  }

  // ── Price Reports ─────────────────────────────────────

  Future<bool> submitPriceReport(
    String stationId,
    double regular,
    double premium, {
    double diesel = 0.0,
    String stationName = '',
    String brand = '',
    String address = '',
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      if (kDebugMode) print('submitPriceReport: No auth user');
      return false;
    }

    try {
      // Step 1: Create report document
      await _firestore.collection('reports').add({
        'userId': authUser.uid,
        'stationId': stationId,
        'reportedRegularPrice': regular,
        'reportedPremiumPrice': premium,
        'reportedDieselPrice': diesel,
        'timestamp': FieldValue.serverTimestamp(),
        'pointsAwarded': 50,
        'status': 'pending',
      });
      if (kDebugMode) print('submitPriceReport: Report doc created');

      // Step 2: Create or update station
      final stationData = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (regular > 0) stationData['regularPrice'] = regular;
      if (premium > 0) stationData['premiumPrice'] = premium;
      if (diesel > 0) stationData['dieselPrice'] = diesel;
      if (stationName.isNotEmpty) stationData['name'] = stationName;
      if (brand.isNotEmpty) stationData['brand'] = brand;
      if (address.isNotEmpty) stationData['address'] = address;
      if (latitude != 0) stationData['latitude'] = latitude;
      if (longitude != 0) stationData['longitude'] = longitude;

      await _firestore
          .collection('stations')
          .doc(stationId)
          .set(stationData, SetOptions(merge: true));
      if (kDebugMode) print('submitPriceReport: Station doc updated');

      // Step 3: Award points — use set+merge so it works even if fields don't exist yet
      await _firestore.collection('users').doc(authUser.uid).set({
        'points': FieldValue.increment(50),
        'reportsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      if (kDebugMode) print('submitPriceReport: User points updated');

      return true;
    } catch (e) {
      if (kDebugMode) print('submitPriceReport ERROR: $e');
      rethrow;
    }
  }
}
