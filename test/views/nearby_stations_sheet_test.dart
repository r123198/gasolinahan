import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/views/nearby_stations_sheet.dart';

StationModel station(String name, String brand, String address) =>
    StationModel.fromMap({
      'name': name,
      'brand': brand,
      'address': address,
      'latitude': 14.5,
      'longitude': 121.0,
    }, name);

void main() {
  final stations = [
    station('Petron Mayapa', 'Petron', 'Calamba'),
    station('Shell EDSA', 'Shell', 'Mandaluyong'),
    station('SeaOil Real', 'SeaOil', 'Calamba'),
  ];

  test('empty query returns every station', () {
    expect(filterStations(stations, '  '), stations);
  });

  test('matches name, brand or address, ignoring case', () {
    expect(filterStations(stations, 'shell').map((s) => s.name), [
      'Shell EDSA',
    ]);
    expect(filterStations(stations, 'CALAMBA').map((s) => s.name), [
      'Petron Mayapa',
      'SeaOil Real',
    ]);
  });

  test('formatDistance rounds to friendly units', () {
    expect(formatDistance(42), '42m');
    expect(formatDistance(456), '460m');
    expect(formatDistance(1234), '1.2km');
  });
}
