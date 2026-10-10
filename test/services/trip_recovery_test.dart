import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/trip_point.dart';
import 'package:gasolinahan/services/trip_tracker.dart';

final _t0 = DateTime(2026, 1, 1, 8);
TripPoint pt(int s, double meters) => TripPoint(
  latitude: 14.5 + meters / 111195.0,
  longitude: 121.0,
  timestamp: _t0.add(Duration(seconds: s)),
);

void main() {
  test('rebuilds a trip from saved points', () {
    final trip = recoverTrip([pt(0, 0), pt(60, 700), pt(120, 1400)]);
    expect(trip, isNotNull);
    expect(trip!.distanceMeters, closeTo(1400, 5));
    expect(trip.startedAt, _t0);
    expect(trip.endedAt, _t0.add(const Duration(seconds: 120)));
  });

  test('returns null when there are no points', () {
    expect(recoverTrip(const []), isNull);
  });

  test('a single point is a trip of zero distance', () {
    final trip = recoverTrip([pt(0, 0)]);
    expect(trip!.distanceMeters, 0);
    expect(trip.isMeaningful, isFalse);
  });
}
