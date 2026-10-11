import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/views/fill_up_location.dart';

StationModel at(String id, double lat, double lng) =>
    StationModel.fromMap({'name': id, 'latitude': lat, 'longitude': lng}, id);

void main() {
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
