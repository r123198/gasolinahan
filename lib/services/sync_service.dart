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

        final reportRef = _firestore.collection('reports').doc();
        batch.set(reportRef, {
          'userId': authUser.uid,
          'stationId': report['stationId'],
          'reportedRegularPrice': report['regularPrice'] ?? 0.0,
          'reportedPremiumPrice': report['premiumPrice'] ?? 0.0,
          'reportedDieselPrice': report['dieselPrice'] ?? 0.0,
          'timestamp': Timestamp.fromDate(
            DateTime.parse(report['timestamp'] as String),
          ),
          'pointsAwarded': 50,
          'status': 'pending',
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
          batch.update(stationRef, updates);
        }

        final userRef = _firestore.collection('users').doc(authUser.uid);
        batch.update(userRef, {
          'points': FieldValue.increment(50),
          'reportsCount': FieldValue.increment(1),
        });

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
