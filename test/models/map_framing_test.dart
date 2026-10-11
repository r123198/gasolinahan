import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/map_framing.dart';
import 'package:gasolinahan/models/station_model.dart';

StationModel at(String id, double lat, double lng) =>
    StationModel.fromMap({'name': id, 'latitude': lat, 'longitude': lng}, id);

void main() {
  final makati = at('makati', 14.55, 121.02);
  final qc = at('qc', 14.65, 121.05);
  final cebu = at('cebu', 10.31, 123.89);
  final noCoords = at('none', 0, 0);

  test('frames nearby stations plus the user', () {
    final points = pointsToFrame(
      [makati, qc, cebu],
      userLat: 14.56,
      userLng: 121.03,
    );
    expect(points, [(14.55, 121.02), (14.65, 121.05), (14.56, 121.03)]);
  });

  test('shows every reported station when none are near the user', () {
    final points = pointsToFrame(
      [makati, cebu],
      userLat: 37.7,
      userLng: -122.4,
    );
    expect(points, [(14.55, 121.02), (10.31, 123.89)]);
  });

  test('without a location it frames every station', () {
    expect(pointsToFrame([makati, qc]), [(14.55, 121.02), (14.65, 121.05)]);
  });

  test('skips stations saved without coordinates', () {
    expect(pointsToFrame([noCoords]), isEmpty);
  });
}
