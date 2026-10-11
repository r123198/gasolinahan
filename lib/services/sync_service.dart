import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'offline_database_service.dart';

class SyncService {
  final OfflineDatabaseService _offlineDb = OfflineDatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<int> syncPendingReports() async {
    if (!await isOnline()) return 0;

    final authUser = _auth.currentUser;
    if (authUser == null) return 0;

    final pending = await _offlineDb.getUnsyncedReports();
    int synced = 0;

    for (final report in pending) {
      try {
        final batch = _firestore.batch();
        final productPrices = decodeProductPrices(report['productPrices']);

        final reportRef = _firestore.collection('reports').doc();
        batch.set(reportRef, {
          'userId': authUser.uid,
          'stationId': report['stationId'],
          'reportedRegularPrice': report['regularPrice'] ?? 0.0,
          'reportedPremiumPrice': report['premiumPrice'] ?? 0.0,
          'reportedDieselPrice': report['dieselPrice'] ?? 0.0,
          'reportedProductPrices': productPrices,
          'timestamp': Timestamp.fromDate(
            DateTime.parse(report['timestamp'] as String),
          ),
          'pointsAwarded': pointsOf(report),
          'pointsReason': report['pointsReason'] ?? '',
          'status': 'accepted',
        });

        final stationId = report['stationId'] as String;
        if (stationId.isNotEmpty) {
          final stationRef = _firestore.collection('stations').doc(stationId);
          final updates = <String, dynamic>{
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          final regular = (report['regularPrice'] as num?) ?? 0.0;
          final premium = (report['premiumPrice'] as num?) ?? 0.0;
          final diesel = (report['dieselPrice'] as num?) ?? 0.0;
          if (regular > 0) updates['regularPrice'] = regular;
          if (premium > 0) updates['premiumPrice'] = premium;
          if (diesel > 0) updates['dieselPrice'] = diesel;
          if (productPrices.isNotEmpty) {
            updates['productPrices'] = productPrices;
          }
          final name = (report['stationName'] as String?) ?? '';
          final brand = (report['brand'] as String?) ?? '';
          final lat = (report['latitude'] as num?) ?? 0;
          final lng = (report['longitude'] as num?) ?? 0;
          if (name.isNotEmpty) updates['name'] = name;
          if (brand.isNotEmpty) updates['brand'] = brand;
          if (lat != 0) updates['latitude'] = lat;
          if (lng != 0) updates['longitude'] = lng;
          // Merge (not update): creates stations first reported offline and
          // keeps products this report didn't include.
          batch.set(stationRef, updates, SetOptions(merge: true));
        }

        // Points worked out when the report was made; in the same batch as
        // the report so a retried sync can't award them twice.
        final userRef = _firestore.collection('users').doc(authUser.uid);
        final points = pointsOf(report);
        batch.set(userRef, {
          'reportsCount': FieldValue.increment(1),
          if (points != 0) ...{
            'points': FieldValue.increment(points),
            'lifetimePoints': FieldValue.increment(points),
          },
        }, SetOptions(merge: true));
        if (points != 0) {
          batch.set(userRef.collection('points_ledger').doc(), {
            'points': points,
            'reason': report['pointsReason'] ?? '',
            'source': 'report:${reportRef.id}',
            'at': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        await _offlineDb.markAsSynced(report['id'] as int);
        synced++;
      } catch (_) {
        // Will retry on next sync
      }
    }

    return synced;
  }
}

/// Points stored on a pending report row (0 for rows saved before points).
int pointsOf(Map<String, dynamic> report) {
  final value = report['pointsAwarded'];
  return value is int ? value : 0;
}

/// Reads the pending_reports.productPrices JSON column; bad data → empty.
Map<String, double> decodeProductPrices(Object? raw) {
  if (raw is! String || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && value is num && value > 0) key: value.toDouble(),
    };
  } on FormatException {
    return const {};
  }
}
