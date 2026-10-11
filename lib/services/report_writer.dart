import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/report_upload.dart';

/// True when the phone has some network (it may still not reach Firebase).
Future<bool> hasNetwork() async {
  final result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
}

final _uploaded = StreamController<void>.broadcast();

/// Fires after reports reach the server (a send or a sync), so screens
/// showing points can re-read them.
Stream<void> get onReportsUploaded => _uploaded.stream;

void notifyReportsUploaded() => _uploaded.add(null);

/// Writes a price report to Firestore: the report, the station's prices,
/// the user's report count and points, and a ledger entry, as ONE batch so
/// a failure never leaves half of it behind.
///
/// The report and ledger documents use ids fixed by [ReportUpload.reportId]
/// and the rules forbid updating either, so if the same report is written
/// twice (a timed-out attempt that later lands, or a sync that crashed
/// before marking its row done) the second batch is rejected whole and no
/// points are awarded twice.
class ReportWriter {
  final FirebaseFirestore _firestore;

  ReportWriter([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// A fresh report id, chosen before the first attempt.
  String newReportId() => _firestore.collection('reports').doc().id;

  Future<void> write(ReportUpload r) async {
    final stationRef = _firestore.collection('stations').doc(r.stationId);
    final stationExists = await _exists(stationRef);

    final reportRef = _firestore.collection('reports').doc(r.reportId);
    final at = r.timestamp;
    final batch = _firestore.batch()
      ..set(reportRef, {
        ...r.reportFields(),
        'timestamp': at == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(at),
      })
      // Merge (not update): creates stations first reported here and keeps
      // products this report didn't include.
      ..set(stationRef, {
        ...r.stationFields(stationExists: stationExists),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(r.userId);
    final points = r.awardedPoints;
    batch.set(userRef, {
      'reportsCount': FieldValue.increment(1),
      if (points != 0) ...{
        'points': FieldValue.increment(points),
        'lifetimePoints': FieldValue.increment(points),
      },
    }, SetOptions(merge: true));
    if (points != 0) {
      batch.set(
        userRef.collection('points_ledger').doc('report_${r.reportId}'),
        {
          'points': points,
          'reason': r.pointsReason,
          'source': 'report:${r.reportId}',
          'at': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  /// Whether [reportId] is already on the server, e.g. after a write was
  /// rejected as a repeat. False when it can't be checked.
  Future<bool> isStored(String reportId) async {
    try {
      final doc = await _firestore
          .collection('reports')
          .doc(reportId)
          .get(const GetOptions(source: Source.server));
      return doc.exists;
    } on FirebaseException {
      // The rules deny reading a report that doesn't exist.
      return false;
    }
  }

  /// Only decides whether name/brand/position may be written, so a failed
  /// lookup counts as "exists": better to skip them than overwrite.
  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get()).exists;
    } on FirebaseException {
      return true;
    }
  }
}
