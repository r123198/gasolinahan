import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';

void main() {
  test('round-trips price, notes and photos through the database map', () {
    final original = FillUp(
      id: 3,
      stationId: 's1',
      stationName: 'SeaOil Mayapa',
      brand: 'SeaOil',
      fuelType: 'regular',
      amountSpent: 755.47,
      liters: 9.213,
      pricePerLiter: 82,
      odometerKm: 9129,
      timestamp: DateTime(2026, 9, 27, 8, 15),
      notes: 'Pricelocq discount',
      photoPaths: const ['/a.jpg', '/b.jpg'],
    );
    final copy = FillUp.fromMap(original.toMap());
    expect(copy.pricePerLiter, 82);
    expect(copy.notes, 'Pricelocq discount');
    expect(copy.photoPaths, ['/a.jpg', '/b.jpg']);
    expect(copy.timestamp, original.timestamp);
  });

  test('reads rows saved before price, notes and photos existed', () {
    final copy = FillUp.fromMap({
      'id': 1,
      'stationId': 's',
      'stationName': 'Shell',
      'brand': 'Shell',
      'fuelType': 'diesel',
      'amountSpent': 500,
      'liters': null,
      'odometerKm': 1000,
      'timestamp': '2026-01-01T00:00:00.000',
    });
    expect(copy.pricePerLiter, isNull);
    expect(copy.notes, '');
    expect(copy.photoPaths, isEmpty);
  });

  test('derives price per liter from amount and liters for old rows', () {
    final fill = FillUp(
      stationId: 's',
      stationName: 'Shell',
      brand: 'Shell',
      fuelType: 'regular',
      amountSpent: 820,
      liters: 10,
      odometerKm: 1000,
      timestamp: DateTime(2026),
    );
    expect(fill.effectivePricePerLiter, 82);
  });
}
