import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/report_upload.dart';
import 'package:gasolinahan/services/offline_database_service.dart';
import 'package:gasolinahan/services/report_writer.dart';
import 'package:gasolinahan/services/sync_service.dart';

/// Queued rows in memory; records the user asked for and rows marked done.
class FakeOfflineDb implements OfflineDatabaseService {
  final rows = <Map<String, dynamic>>[];
  final queriedFor = <String>[];
  final synced = <int>[];

  @override
  Future<List<Map<String, dynamic>>> getUnsyncedReports({
    required String userId,
  }) async {
    queriedFor.add(userId);
    return [
      for (final r in rows)
        if (r['userId'] == userId && !synced.contains(r['id'])) r,
    ];
  }

  @override
  Future<void> markAsSynced(int id) async => synced.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records writes; fails those in [failing], which [isStored] may claim are
/// already on the server. [gate] holds every write until completed.
class FakeWriter implements ReportWriter {
  final written = <ReportUpload>[];
  final failing = <String>{};
  final stored = <String>{};
  Completer<void>? gate;

  @override
  Future<void> write(ReportUpload r) async {
    await gate?.future;
    if (failing.contains(r.reportId)) throw Exception('rejected');
    written.add(r);
  }

  @override
  Future<bool> isStored(String reportId) async => stored.contains(reportId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _row(int id, {String userId = 'uid-1', int pending = 0}) =>
    {
      'id': id,
      'userId': userId,
      'stationId': 'st-$id',
      'timestamp': '2026-10-01T08:00:00.000',
      'pointsAwarded': 5,
      'isPending': pending,
      'remoteId': 'r$id',
    };

void main() {
  late FakeOfflineDb db;
  late FakeWriter writer;
  String? uid;
  var online = true;

  SyncService service() => SyncService(
    offlineDb: db,
    writer: writer,
    currentUid: () => uid,
    isOnline: () async => online,
  );

  setUp(() {
    db = FakeOfflineDb();
    writer = FakeWriter();
    uid = 'uid-1';
    online = true;
  });

  test('uploads only the signed-in user\'s rows, as that user', () async {
    db.rows.addAll([_row(1), _row(2, userId: 'uid-2')]);

    final count = await service().syncPendingReports();

    expect(count, 1);
    expect(db.queriedFor, ['uid-1']);
    expect(writer.written.single.userId, 'uid-1');
    expect(writer.written.single.reportId, 'r1');
    expect(db.synced, [1]);
  });

  test('keeps a held-for-review report pending with no points', () async {
    db.rows.add(_row(1, pending: 1));

    await service().syncPendingReports();

    expect(writer.written.single.status, 'pending');
    expect(writer.written.single.awardedPoints, 0);
  });

  test('overlapping calls share one run', () async {
    db.rows.add(_row(1));
    writer.gate = Completer<void>();

    final first = service().syncPendingReports();
    final second = service().syncPendingReports();
    writer.gate!.complete();

    expect(await first, 1);
    expect(await second, 1);
    expect(writer.written, hasLength(1));
    expect(db.queriedFor, hasLength(1));
  });

  test('a repeat already on the server is marked done', () async {
    db.rows.add(_row(1));
    writer.failing.add('r1');
    writer.stored.add('r1');

    expect(await service().syncPendingReports(), 1);
    expect(db.synced, [1]);
  });

  test('a failed upload stays queued for next time', () async {
    db.rows.addAll([_row(1), _row(2)]);
    writer.failing.add('r1');

    expect(await service().syncPendingReports(), 1);
    expect(db.synced, [2]);
  });

  test('does nothing offline or signed out', () async {
    db.rows.add(_row(1));

    online = false;
    expect(await service().syncPendingReports(), 0);
    online = true;
    uid = null;
    expect(await service().syncPendingReports(), 0);
    expect(writer.written, isEmpty);
  });

  test('decodes stored product prices', () {
    expect(decodeProductPrices('{"XCS": 61.2, "Turbo Diesel": 55}'), {
      'XCS': 61.2,
      'Turbo Diesel': 55.0,
    });
  });

  test('bad or missing data decodes to nothing', () {
    expect(decodeProductPrices(null), isEmpty);
    expect(decodeProductPrices('not json'), isEmpty);
    expect(decodeProductPrices('{"XCS": "x", "Bad": -1}'), isEmpty);
  });

  test('pending rows carry their points; old rows earn none', () {
    expect(pointsOf({'pointsAwarded': 6}), 6);
    expect(pointsOf({}), 0);
    expect(pointsOf({'pointsAwarded': 'x'}), 0);
  });
}
