import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/trip_model.dart';
import 'package:gasolinahan/models/trip_point.dart';
import 'package:gasolinahan/services/driving_activity_source.dart';
import 'package:gasolinahan/services/location_source.dart';
import 'package:gasolinahan/services/trip_service.dart';
import 'package:gasolinahan/services/trip_tracker.dart';
import 'package:gasolinahan/viewmodels/trip_viewmodel.dart';

class FakeSource implements LocationSource {
  final controller = StreamController<TripPoint>.broadcast();
  bool allowed = true;
  final precise = <bool>[];

  @override
  Stream<TripPoint> get points => controller.stream;
  @override
  Future<bool> start() async => allowed;
  @override
  Future<void> setPrecise(bool value) async => precise.add(value);
}

class FakeActivity implements DrivingActivitySource {
  final controller = StreamController<bool>.broadcast();
  bool available = true;

  @override
  Stream<bool> get inVehicle => controller.stream;
  @override
  Future<bool> start() async => available;
}

class FakeService extends TripService {
  final finished = <FinishedTrip>[];
  final active = <int, List<TripPoint>>{};
  final deleted = <int>[];
  var _nextId = 1;

  @override
  Future<int> beginActive(DateTime startedAt, List<TripPoint> points) async {
    final id = _nextId++;
    active[id] = [...points];
    return id;
  }

  @override
  Future<void> appendPoint(int tripId, TripPoint point) async =>
      active[tripId]!.add(point);

  @override
  Future<void> finalize(int tripId, FinishedTrip trip) async {
    active.remove(tripId);
    finished.add(trip);
  }

  @override
  Future<List<int>> activeTripIds() async => active.keys.toList();

  @override
  Future<List<TripPoint>> pointsFor(int tripId) async => active[tripId] ?? [];

  @override
  Future<void> delete(int tripId) async {
    active.remove(tripId);
    deleted.add(tripId);
  }

  @override
  Future<List<Trip>> getAll() async => [
    for (final t in finished)
      Trip(
        id: 1,
        startedAt: t.startedAt,
        endedAt: t.endedAt,
        distanceMeters: t.distanceMeters,
      ),
  ];
}

final _t0 = DateTime(2026, 1, 1, 8);
TripPoint pt(int s, double meters, {double speed = 12}) => TripPoint(
  latitude: 14.5 + meters / 111195.0,
  longitude: 121.0,
  timestamp: _t0.add(Duration(seconds: s)),
  speedMps: speed,
  accuracyMeters: 5,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeSource source;
  late FakeService service;
  late FakeActivity activity;
  late TripViewModel vm;

  setUp(() {
    source = FakeSource();
    service = FakeService();
    activity = FakeActivity();
    vm = TripViewModel(source: source, service: service, activity: activity);
  });

  tearDown(() => vm.dispose());

  test('shares every location sample with other features', () async {
    await vm.startMonitoring();
    final received = <TripPoint>[];
    final sub = vm.locationUpdates.listen(received.add);
    source.controller.add(pt(0, 0, speed: 0));
    source.controller.add(pt(5, 10, speed: 2));
    await settle();
    expect(received, hasLength(2));
    await sub.cancel();
  });

  test('reports permission denied and does not monitor', () async {
    source.allowed = false;
    await vm.startMonitoring();
    expect(vm.permissionDenied, isTrue);
    expect(vm.isMonitoring, isFalse);
  });

  test('starts tracking by itself once driving speed is sustained', () async {
    await vm.startMonitoring();
    for (var i = 1; i <= 60; i++) {
      source.controller.add(pt(i, 12.0 * i));
      await settle();
    }
    expect(vm.isTracking, isTrue);
    expect(source.precise.last, isTrue);
  });

  test('saves the trip automatically when driving ends', () async {
    await vm.startMonitoring();
    for (var i = 1; i <= 120; i++) {
      source.controller.add(pt(i, 12.0 * i));
      await settle();
    }
    for (var i = 1; i <= 310; i++) {
      source.controller.add(pt(120 + i, 1440, speed: 0));
      await settle();
    }
    expect(vm.isTracking, isFalse);
    expect(service.finished, hasLength(1));
    expect(vm.history, hasLength(1));
    expect(source.precise.last, isFalse);
  });

  test('does not save a trip shorter than 500 m', () async {
    await vm.startMonitoring();
    source.controller.add(pt(0, 0, speed: 0));
    await settle();
    await vm.trackNow();
    source.controller.add(pt(5, 100, speed: 5));
    await settle();
    await vm.stopNow();
    expect(service.finished, isEmpty);
  });

  test('saves each point while driving so a crash loses nothing', () async {
    await vm.startMonitoring();
    for (var i = 1; i <= 80; i++) {
      source.controller.add(pt(i, 12.0 * i));
      await settle();
    }
    expect(service.active, hasLength(1));
    expect(service.active.values.single.length, vm.livePoints.length);
  });

  test('finishes a trip interrupted by a crash on the next launch', () async {
    service.active[7] = [for (var i = 0; i <= 10; i++) pt(i * 10, 100.0 * i)];
    await vm.startMonitoring();
    expect(service.active, isEmpty);
    expect(service.finished, hasLength(1));
    expect(service.finished.single.distanceMeters, closeTo(1000, 10));
  });

  test('discards an interrupted trip that was too short to matter', () async {
    service.active[3] = [pt(0, 0), pt(10, 50)];
    await vm.startMonitoring();
    expect(service.finished, isEmpty);
    expect(service.deleted, [3]);
  });

  test('samples precisely once the phone says you are in a vehicle', () async {
    await vm.startMonitoring();
    activity.controller.add(true);
    await settle();
    expect(source.precise.last, isTrue);
  });

  test(
    'goes back to sparing mode when you are no longer in a vehicle',
    () async {
      await vm.startMonitoring();
      activity.controller.add(true);
      await settle();
      activity.controller.add(false);
      await settle();
      expect(source.precise.last, isFalse);
    },
  );

  test('the hint lets a trip start within 20 seconds of driving', () async {
    await vm.startMonitoring();
    activity.controller.add(true);
    await settle();
    for (var i = 1; i <= 20; i++) {
      source.controller.add(pt(i, 12.0 * i));
      await settle();
    }
    expect(vm.isTracking, isTrue);
  });

  test('still works when activity recognition is unavailable', () async {
    activity.available = false;
    await vm.startMonitoring();
    expect(vm.isMonitoring, isTrue);
  });

  test(
    'Track me starts on the next sample when none has arrived yet',
    () async {
      await vm.trackNow();
      expect(vm.isTracking, isTrue);
      source.controller.add(pt(0, 0, speed: 0));
      await settle();
      expect(vm.isTracking, isTrue);
    },
  );

  test('Track me then stop saves a meaningful trip', () async {
    await vm.startMonitoring();
    source.controller.add(pt(0, 0, speed: 0));
    await settle();
    await vm.trackNow();
    source.controller.add(pt(60, 800, speed: 13));
    await settle();
    await vm.stopNow();
    expect(service.finished, hasLength(1));
    expect(vm.isTracking, isFalse);
  });
}
