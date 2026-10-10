import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/models/trip_point.dart';
import 'package:gasolinahan/services/visit_detector.dart';

const _metersPerDegreeLat = 111195.0;
final _t0 = DateTime(2026, 1, 1, 8);

StationModel station(String id, double metersNorth, {double lat0 = 14.5}) {
  return StationModel(
    id: id,
    name: 'Station $id',
    brand: 'Shell',
    address: '',
    latitude: lat0 + metersNorth / _metersPerDegreeLat,
    longitude: 121.0,
    regularPrice: 60,
    premiumPrice: 0,
    dieselPrice: 0,
    lastUpdated: DateTime(2026),
  );
}

TripPoint pt(
  int seconds,
  double metersNorth, {
  double? speed = 0,
  double accuracy = 10,
}) {
  return TripPoint(
    latitude: 14.5 + metersNorth / _metersPerDegreeLat,
    longitude: 121.0,
    timestamp: _t0.add(Duration(seconds: seconds)),
    speedMps: speed,
    accuracyMeters: accuracy,
  );
}

DateTime at(int seconds) => _t0.add(Duration(seconds: seconds));

void main() {
  late VisitDetector detector;
  final shell = station('shell', 1000);

  setUp(() {
    detector = VisitDetector()..stations = [shell, station('far', 5000)];
  });

  test('confirms a visit after three minutes stopped at a station', () {
    expect(detector.onPoint(pt(0, 1010)), isNull);
    expect(detector.onTick(at(120)), isNull);
    expect(detector.onTick(at(181))?.id, 'shell');
  });

  test('counts the stay even when no new GPS samples arrive', () {
    detector.onPoint(pt(0, 1000));
    // No samples for 4 minutes: the phone sends none while standing still.
    expect(detector.onTick(at(240))?.id, 'shell');
  });

  test('a later sample also confirms the visit', () {
    detector.onPoint(pt(0, 1000));
    expect(detector.onPoint(pt(200, 1005))?.id, 'shell');
  });

  test('only confirms once per visit', () {
    detector.onPoint(pt(0, 1000));
    expect(detector.onTick(at(200)), isNotNull);
    expect(detector.onTick(at(400)), isNull);
  });

  test('driving past at speed is not a visit', () {
    detector.onPoint(pt(0, 990, speed: 12));
    detector.onPoint(pt(5, 1050, speed: 12));
    expect(detector.onTick(at(300)), isNull);
  });

  test('leaving before three minutes cancels the visit', () {
    detector.onPoint(pt(0, 1000));
    detector.onPoint(pt(100, 1300, speed: 10));
    expect(detector.onTick(at(300)), isNull);
  });

  test('stopping somewhere that is not a station is ignored', () {
    detector.onPoint(pt(0, 3000));
    expect(detector.onTick(at(600)), isNull);
  });

  test('ignores inaccurate readings', () {
    detector.onPoint(pt(0, 1000, accuracy: 200));
    expect(detector.onTick(at(600)), isNull);
  });

  test('does not nudge the same station again within the cooldown', () {
    detector.onPoint(pt(0, 1000));
    expect(detector.onTick(at(200)), isNotNull);
    detector.onPoint(pt(300, 1500, speed: 10)); // leave
    detector.onPoint(pt(3600, 1000)); // back an hour later
    expect(detector.onTick(at(3900)), isNull);
  });

  test('nudges the same station again after the cooldown', () {
    detector.onPoint(pt(0, 1000));
    detector.onTick(at(200));
    detector.onPoint(pt(300, 1500, speed: 10));
    detector.onPoint(pt(4 * 3600, 1000));
    expect(detector.onTick(at(4 * 3600 + 200))?.id, 'shell');
  });

  test('picks the nearest of two stations close together', () {
    detector.stations = [station('a', 1000), station('b', 1040)];
    detector.onPoint(pt(0, 1035));
    expect(detector.onTick(at(200))?.id, 'b');
  });

  test('ignores stations without coordinates', () {
    detector.stations = [
      StationModel(
        id: 'blank',
        name: 'Unknown Station',
        brand: '',
        address: '',
        latitude: 0,
        longitude: 0,
        regularPrice: 60,
        premiumPrice: 0,
        dieselPrice: 0,
        lastUpdated: DateTime(2026),
      ),
    ];
    detector.onPoint(
      TripPoint(
        latitude: 0,
        longitude: 0,
        timestamp: _t0,
        speedMps: 0,
        accuracyMeters: 5,
      ),
    );
    expect(detector.onTick(at(600)), isNull);
  });

  test('isWatching is true only while at a station', () {
    expect(detector.isWatching, isFalse);
    detector.onPoint(pt(0, 1000));
    expect(detector.isWatching, isTrue);
    detector.onPoint(pt(60, 2000, speed: 10));
    expect(detector.isWatching, isFalse);
  });
}
