import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/services/fill_up_remote.dart';
import 'package:gasolinahan/services/fill_up_service.dart';
import 'package:gasolinahan/viewmodels/fill_up_viewmodel.dart';

/// In-memory stand-in for the SQLite table.
class MemoryFillUpService extends FillUpService {
  final rows = <int, FillUp>{};
  var _nextId = 1;

  @override
  Future<List<FillUp>> getAll({String? ownerUid}) async => [
    for (final f in rows.values)
      if (f.ownerUid == null || f.ownerUid == ownerUid) f,
  ];

  @override
  Future<int> insert(FillUp fillUp) async {
    final id = _nextId++;
    rows[id] = fillUp.copyWith(id: id);
    return id;
  }

  @override
  Future<void> update(FillUp fillUp) async => rows[fillUp.id!] = fillUp;

  @override
  Future<void> delete(int id) async => rows.remove(id);
}

class FakeRemote implements FillUpRemote {
  final docs = <String, FillUp>{};
  var reachable = true;
  var _n = 0;

  @override
  String newId(String uid) => 'r${_n++}';

  @override
  Future<List<FillUp>> fetchAll(String uid) async {
    if (!reachable) throw Exception('offline');
    return docs.values.toList();
  }

  @override
  Future<void> save(String uid, FillUp fillUp) async =>
      docs[fillUp.remoteId!] = fillUp.copyWith();

  @override
  Future<void> delete(String uid, String remoteId) async =>
      docs.remove(remoteId);
}

FillUp fill({double odo = 1000, String? remoteId, String? owner}) => FillUp(
  stationId: 's',
  stationName: 'Shell',
  brand: 'Shell',
  fuelType: 'regular',
  amountSpent: 500,
  odometerKm: odo,
  timestamp: DateTime(2026, 10, 1),
  remoteId: remoteId,
  ownerUid: owner,
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  late MemoryFillUpService local;
  late FakeRemote remote;
  late List<(String, int, String)> awards;
  String? uid;

  FillUpViewModel vm() => FillUpViewModel(
    service: local,
    remote: remote,
    currentUserId: () => uid,
    awardPoints: (uid, points, reason, source) async =>
        awards.add((uid, points, reason)),
  );

  setUp(() {
    local = MemoryFillUpService();
    remote = FakeRemote();
    awards = [];
    uid = 'me';
  });

  test('a new fill-up is saved here and sent to the cloud', () async {
    final model = vm();
    expect(await model.add(fill()), isTrue);
    await pumpEventQueue();

    final saved = local.rows.values.single;
    expect(saved.ownerUid, 'me');
    expect(saved.remoteId, isNotNull);
    expect(remote.docs.keys, [saved.remoteId]);
  });

  test('loading brings in fill-ups logged on another phone', () async {
    remote.docs['x'] = fill(remoteId: 'x', odo: 2000);
    final model = vm();
    await model.load();

    expect(model.fillUps.map((f) => f.odometerKm), [2000]);
    expect(local.rows.values.single.ownerUid, 'me');
  });

  test('old local-only fill-ups are claimed and uploaded', () async {
    await local.insert(fill(odo: 1500));
    final model = vm();
    await model.load();
    await pumpEventQueue();

    final row = local.rows.values.single;
    expect(row.ownerUid, 'me');
    expect(remote.docs[row.remoteId]?.odometerKm, 1500);
  });

  test('without a connection the local log still shows', () async {
    await local.insert(fill(odo: 1500, owner: 'me', remoteId: 'a'));
    remote.reachable = false;
    final model = vm();
    await model.load();

    expect(model.fillUps, hasLength(1));
    expect(model.errorMessage, isNull);
  });

  test('deleting removes the cloud copy too', () async {
    final model = vm();
    await model.add(fill());
    await pumpEventQueue();
    await model.remove(model.fillUps.single);
    await pumpEventQueue();

    expect(local.rows, isEmpty);
    expect(remote.docs, isEmpty);
  });

  test('signed out: nothing is sent to the cloud', () async {
    uid = null;
    final model = vm();
    await model.add(fill());
    await model.load();
    await pumpEventQueue();

    expect(remote.docs, isEmpty);
    expect(model.fillUps, hasLength(1));
  });

  test("another account's fill-ups stay hidden", () async {
    await local.insert(fill(odo: 900, owner: 'someone-else', remoteId: 'z'));
    final model = vm();
    await model.load();
    expect(model.fillUps, isEmpty);
  });

  group('points', () {
    test('the first fill-up earns its points plus the head start', () async {
      final model = vm();
      await model.add(fill());
      await pumpEventQueue();

      // 1 logged + 2 first fill-up (no product, so not "complete").
      expect(model.lastAward?.points, 3);
      expect(awards.single.$2, 3);
      expect(local.rows.values.single.pointsAwarded, 3);
    });

    test('deleting a fill-up takes its points back', () async {
      final model = vm();
      await model.add(fill());
      await pumpEventQueue();
      await model.remove(model.fillUps.single);
      await pumpEventQueue();

      expect(awards.map((a) => a.$2), [3, -3]);
    });

    test('signed out: no points', () async {
      uid = null;
      final model = vm();
      await model.add(fill());
      await pumpEventQueue();
      expect(awards, isEmpty);
      expect(model.lastAward, isNull);
    });
  });
}
