import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/trip_point.dart';
import 'package:gasolinahan/services/trip_tracker.dart';

final _t0 = DateTime(2026, 1, 1, 8);
const _metersPerDegreeLat = 111195.0;

/// A point [metersNorth] of the origin, [seconds] after the start.
TripPoint pt(
  int seconds,
  double metersNorth, {
  double? speed,
  double accuracy = 5,
}) {
  return TripPoint(
    latitude: 14.5 + metersNorth / _metersPerDegreeLat,
    longitude: 121.0,
    timestamp: _t0.add(Duration(seconds: seconds)),
    speedMps: speed,
    accuracyMeters: accuracy,
  );
}

/// Drives at [speed] m/s for [seconds], one sample per second, starting at
/// [fromSecond] / [fromMeters]. Returns the updates produced.
List<TrackerUpdate> drive(
  TripTracker tracker, {
  required int fromSecond,
  required double fromMeters,
  required int seconds,
  double speed = 12,
}) {
  final updates = <TrackerUpdate>[];
  for (var i = 1; i <= seconds; i++) {
    updates.add(
      tracker.onPoint(pt(fromSecond + i, fromMeters + speed * i, speed: speed)),
    );
  }
  return updates;
}

void main() {
  group('auto start', () {
    test('stays idle while stationary', () {
      final tracker = TripTracker();
      for (var i = 0; i < 120; i++) {
        tracker.onPoint(pt(i, 0, speed: 0));
      }
      expect(tracker.isTracking, isFalse);
    });

    test('does not start on a brief burst of speed', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 10);
      expect(tracker.isTracking, isFalse);
    });

    test(
      'starts after sustained driving speed and keeps the buffered points',
      () {
        final tracker = TripTracker();
        final updates = drive(
          tracker,
          fromSecond: 0,
          fromMeters: 0,
          seconds: 60,
        );

        expect(tracker.isTracking, isTrue);
        expect(
          updates.where((u) => u.event == TrackerEvent.started),
          hasLength(1),
        );
        expect(tracker.points.length, greaterThan(30));
      },
    );

    test('a slow crawl never starts a trip', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 120, speed: 2);
      expect(tracker.isTracking, isFalse);
    });

    test('derives speed from movement when the platform reports none', () {
      final tracker = TripTracker();
      for (var i = 1; i <= 60; i++) {
        tracker.onPoint(pt(i, 12.0 * i));
      }
      expect(tracker.isTracking, isTrue);
    });
  });

  group('driving hint', () {
    test('starts sooner when the phone senses it is in a vehicle', () {
      final tracker = TripTracker()..drivingHint = true;
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 20);
      expect(tracker.isTracking, isTrue);
    });

    test('without the hint 20 seconds is not enough', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 20);
      expect(tracker.isTracking, isFalse);
    });

    test('the hint alone never starts a trip while standing still', () {
      final tracker = TripTracker()..drivingHint = true;
      for (var i = 0; i < 120; i++) {
        tracker.onPoint(pt(i, 0, speed: 0));
      }
      expect(tracker.isTracking, isFalse);
    });
  });

  group('distance', () {
    test('sums the distance travelled', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 100);
      // 1200 m total; the first ~40 s are buffered then included.
      expect(tracker.distanceMeters, closeTo(1188, 30));
    });

    test('ignores inaccurate readings', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 60);
      final before = tracker.distanceMeters;
      tracker.onPoint(pt(61, 5000, speed: 12, accuracy: 200));
      expect(tracker.distanceMeters, before);
    });

    test('rejects an impossible GPS jump', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 60);
      final before = tracker.distanceMeters;
      tracker.onPoint(pt(61, 50000, speed: 12));
      expect(tracker.distanceMeters, before);
    });

    test('ignores jitter smaller than the minimum step', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 60);
      final before = tracker.distanceMeters;
      tracker.onPoint(pt(61, 12.0 * 60 + 3, speed: 12));
      expect(tracker.distanceMeters, before);
    });
  });

  group('auto stop', () {
    test('keeps tracking through a short red light', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 60);
      for (var i = 1; i <= 90; i++) {
        tracker.onPoint(pt(60 + i, 720, speed: 0));
      }
      expect(tracker.isTracking, isTrue);
    });

    test('ends the trip after being stopped for five minutes', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 120);
      final lastMoving = _t0.add(const Duration(seconds: 120));

      TrackerUpdate? ended;
      for (var i = 1; i <= 360; i++) {
        final u = tracker.onPoint(pt(120 + i, 1440, speed: 0));
        if (u.event == TrackerEvent.ended) ended = u;
      }

      expect(ended, isNotNull);
      expect(tracker.isTracking, isFalse);
      expect(ended!.finishedTrip!.endedAt, lastMoving);
      expect(ended.finishedTrip!.distanceMeters, greaterThan(1000));
    });

    test('can start a second trip after the first ends', () {
      final tracker = TripTracker();
      drive(tracker, fromSecond: 0, fromMeters: 0, seconds: 120);
      for (var i = 1; i <= 360; i++) {
        tracker.onPoint(pt(120 + i, 1440, speed: 0));
      }
      drive(tracker, fromSecond: 600, fromMeters: 1440, seconds: 80);
      expect(tracker.isTracking, isTrue);
    });
  });

  group('manual control', () {
    test('startManual tracks immediately and stopManual returns the trip', () {
      final tracker = TripTracker();
      tracker.startManual(pt(0, 0, speed: 0));
      expect(tracker.isTracking, isTrue);
      tracker.onPoint(pt(5, 100, speed: 5));
      final trip = tracker.stopManual(_t0.add(const Duration(seconds: 6)));
      expect(trip!.distanceMeters, closeTo(100, 5));
      expect(tracker.isTracking, isFalse);
    });

    test('a manual trip is not auto-stopped while parked briefly', () {
      final tracker = TripTracker();
      tracker.startManual(pt(0, 0, speed: 0));
      for (var i = 1; i <= 120; i++) {
        tracker.onPoint(pt(i, 0, speed: 0));
      }
      expect(tracker.isTracking, isTrue);
    });
  });

  group('FinishedTrip', () {
    test('is not meaningful when shorter than 500 m', () {
      final tracker = TripTracker();
      tracker.startManual(pt(0, 0, speed: 0));
      tracker.onPoint(pt(5, 100, speed: 5));
      final trip = tracker.stopManual(_t0.add(const Duration(seconds: 6)))!;
      expect(trip.isMeaningful, isFalse);
    });
  });
}
