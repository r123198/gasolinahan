import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/report_upload.dart';
import 'offline_database_service.dart';
import 'report_writer.dart';

export '../models/report_upload.dart' show decodeProductPrices, pointsOf;

/// Uploads price reports saved while offline.
class SyncService {
  final OfflineDatabaseService _offlineDb;
  final ReportWriter? _writerOverride;
  final String? Function() _currentUid;
  final Future<bool> Function() _isOnline;

  SyncService({
    OfflineDatabaseService? offlineDb,
    ReportWriter? writer,
    String? Function()? currentUid,
    Future<bool> Function()? isOnline,
  }) : _offlineDb = offlineDb ?? OfflineDatabaseService(),
       _writerOverride = writer,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _isOnline = isOnline ?? hasNetwork;

  ReportWriter get _writer => _writerOverride ?? ReportWriter();

  /// The run in progress, shared by every caller so runs never overlap
  /// (two at once would upload the same rows).
  static Future<int>? _running;

  /// Auth and connectivity listeners, kept for the app's lifetime.
  static List<StreamSubscription<Object?>>? _triggers;

  /// Syncs on sign-in (including an already signed-in start-up) and
  /// whenever the connection comes back. Safe to call more than once.
  static void startAutoSync() {
    if (_triggers != null) return;
    final service = SyncService();
    _triggers = [
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) unawaited(service.syncPendingReports());
      }),
      Connectivity().onConnectivityChanged.listen((result) {
        if (!result.contains(ConnectivityResult.none)) {
          unawaited(service.syncPendingReports());
        }
      }),
    ];
  }

  Future<bool> isOnline() => _isOnline();

  /// Uploads the signed-in user's queued reports; returns how many went up.
  /// Never throws: whatever fails stays queued for the next run.
  Future<int> syncPendingReports() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<int> _sync() async {
    try {
      if (!await _isOnline()) return 0;
      // Rows belong to whoever made them; another account signed in on
      // this phone mustn't be credited with them.
      final uid = _currentUid();
      if (uid == null) return 0;

      final pending = await _offlineDb.getUnsyncedReports(userId: uid);
      var synced = 0;
      for (final row in pending) {
        if (await _upload(row, uid)) synced++;
      }
      if (synced > 0) notifyReportsUploaded();
      return synced;
    } on Exception catch (e) {
      debugPrint('Report sync failed: $e');
      return 0;
    }
  }

  Future<bool> _upload(Map<String, dynamic> row, String uid) async {
    final upload = ReportUpload.fromPendingRow(row, uid: uid);
    try {
      await _writer.write(upload);
    } on Exception catch (e) {
      // A repeat of a report already on the server is rejected; that row
      // is done. Anything else is retried on the next sync.
      if (!await _writer.isStored(upload.reportId)) {
        debugPrint('Report ${upload.reportId} not synced: $e');
        return false;
      }
    }
    await _offlineDb.markAsSynced(row['id'] as int);
    return true;
  }
}
