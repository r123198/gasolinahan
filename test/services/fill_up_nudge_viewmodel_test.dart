import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/models/trip_point.dart';
import 'package:gasolinahan/services/nudge_notifier.dart';
import 'package:gasolinahan/viewmodels/fill_up_nudge_viewmodel.dart';

class FakeNotifier implements NudgeNotifier {
  final shown = <StationModel>[];
  void Function(String stationId)? onTap;
  String? launchedWith;

  @override
  Future<void> init({required void Function(String stationId) onTap}) async {
    this.onTap = onTap;
  }

  @override
  Future<void> showFillUpNudge(StationModel station) async =>
      shown.add(station);

  @override
  Future<String?> launchStationId() async => launchedWith;
}

const _metersPerDegreeLat = 111195.0;
final _t0 = DateTime(2026, 1, 1, 8);

final shell = StationModel(
  id: 'shell',
  name: 'Shell Ayala',
  brand: 'Shell',
  address: '',
  latitude: 14.5 + 1000 / _metersPerDegreeLat,
  longitude: 121.0,
  regularPrice: 60,
  premiumPrice: 0,
  dieselPrice: 0,
  lastUpdated: DateTime(2026),
);

TripPoint pt(int seconds) => TripPoint(
  latitude: shell.latitude,
  longitude: shell.longitude,
  timestamp: _t0.add(Duration(seconds: seconds)),
  speedMps: 0,
  accuracyMeters: 10,
);

FillUp loggedAt(String stationId, DateTime at) => FillUp(
  stationId: stationId,
  stationName: 'Shell Ayala',
  brand: 'Shell',
  fuelType: 'regular',
  amountSpent: 1000,
  odometerKm: 10000,
  timestamp: at,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<TripPoint> points;
  late FakeNotifier notifier;
  late DateTime now;
  late List<FillUp> fills;
  late FillUpNudgeViewModel vm;

  setUp(() async {
    points = StreamController<TripPoint>.broadcast();
    notifier = FakeNotifier();
    now = _t0;
    fills = [];
    vm = FillUpNudgeViewModel(
      notifier: notifier,
      clock: () => now,
      tickEvery: const Duration(days: 1), // ticks driven by hand in tests
    );
    vm.updateStations([shell]);
    vm.updateFillUps(fills);
    await vm.start(points.stream);
  });

  tearDown(() => vm.dispose());

  test('notifies after three minutes stopped at a station', () async {
    points.add(pt(0));
    await settle();
    now = _t0.add(const Duration(minutes: 4));
    await vm.tick();
    expect(notifier.shown.single.id, 'shell');
  });

  test('stays quiet when a fill-up there was already logged', () async {
    vm.updateFillUps([loggedAt('shell', _t0.add(const Duration(minutes: 1)))]);
    points.add(pt(0));
    await settle();
    now = _t0.add(const Duration(minutes: 4));
    await vm.tick();
    expect(notifier.shown, isEmpty);
  });

  test('an old fill-up at the same station does not block the nudge', () async {
    vm.updateFillUps([
      loggedAt('shell', _t0.subtract(const Duration(days: 3))),
    ]);
    points.add(pt(0));
    await settle();
    now = _t0.add(const Duration(minutes: 4));
    await vm.tick();
    expect(notifier.shown, hasLength(1));
  });

  test(
    'tapping the notification queues the station for the fill-up form',
    () async {
      var notified = 0;
      vm.addListener(() => notified++);
      notifier.onTap!('shell');
      expect(notified, 1);
      expect(vm.takePendingStation()?.id, 'shell');
      expect(vm.takePendingStation(), isNull);
    },
  );

  test('a tap for an unknown station is ignored', () async {
    notifier.onTap!('gone');
    expect(vm.takePendingStation(), isNull);
  });

  test('opening the app from a notification queues that station', () async {
    final other = FillUpNudgeViewModel(
      notifier: notifier..launchedWith = 'shell',
      clock: () => now,
      tickEvery: const Duration(days: 1),
    )..updateStations([shell]);
    await other.start(points.stream);
    expect(other.takePendingStation()?.id, 'shell');
    other.dispose();
  });

  test('a launch station is kept until stations finish loading', () async {
    final other = FillUpNudgeViewModel(
      notifier: notifier..launchedWith = 'shell',
      clock: () => now,
      tickEvery: const Duration(days: 1),
    );
    await other.start(points.stream);
    expect(other.takePendingStation(), isNull);
    other.updateStations([shell]);
    expect(other.takePendingStation()?.id, 'shell');
    other.dispose();
  });
}
