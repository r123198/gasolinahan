import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/services/current_location.dart';
import 'package:gasolinahan/services/place_lookup.dart';
import 'package:gasolinahan/views/fill_up_location.dart';

StationModel at(String id, double lat, double lng) =>
    StationModel.fromMap({'name': id, 'latitude': lat, 'longitude': lng}, id);

Future<GeoFix?> _atMayapa() async =>
    const GeoFix(latitude: 14.2117, longitude: 121.1653);

Future<GeoFix?> _noFix() async => null;

/// A place lookup still waiting on the network.
class _StalledLookup extends PlaceLookup {
  final pending = Completer<PlaceGuess?>();

  @override
  Future<PlaceGuess?> lookUp(double lat, double lng) => pending.future;
}

void main() {
  test('hands over coordinates before the place lookup finishes', () async {
    final lookup = _StalledLookup();
    (double, double)? fix;
    final guess = guessFillUpLocation(
      reportedStations: const [],
      locate: _atMayapa,
      lookup: lookup,
      onFix: (lat, lng) => fix = (lat, lng),
    );
    await pumpEventQueue();
    expect(fix, (14.2117, 121.1653));

    lookup.pending.complete(null);
    expect((await guess)?.latitude, 14.2117);
  });

  test('gives up quietly when the phone has no fix', () async {
    var fixes = 0;
    final guess = await guessFillUpLocation(
      reportedStations: [at('near', 14.2118, 121.1654)],
      locate: _noFix,
      onFix: (_, _) => fixes++,
    );
    expect(guess, isNull);
    expect(fixes, 0);
  });

  test('names the reported station you are standing at', () async {
    final guess = await guessFillUpLocation(
      reportedStations: [at('near', 14.2118, 121.1654)],
      locate: _atMayapa,
    );
    expect(guess?.reportedStation?.id, 'near');
    expect(guess?.place, isNull);
  });

  test('finds the reported station you are standing at', () {
    final near = at('near', 14.21180, 121.16540); // ~10 m away
    final far = at('far', 14.2200, 121.1700); // ~1 km away
    expect(reportedStationAt([far, near], 14.2117, 121.1653)?.id, 'near');
  });

  test('nothing within 150 m means no reported station', () {
    expect(
      reportedStationAt([at('far', 14.2200, 121.1700)], 14.2117, 121.1653),
      isNull,
    );
  });

  test('ignores stations without coordinates', () {
    expect(reportedStationAt([at('none', 0, 0)], 0.0005, 0.0005), isNull);
  });
}
