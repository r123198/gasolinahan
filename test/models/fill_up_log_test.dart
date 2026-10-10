import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_log.dart';
import 'package:gasolinahan/models/fill_up_model.dart';

FillUp fill(double spent, double odo, int day, {double? liters, int? id}) {
  return FillUp(
    id: id,
    stationId: 's',
    stationName: 'SeaOil Mayapa',
    brand: 'SeaOil',
    fuelType: 'regular',
    amountSpent: spent,
    liters: liters,
    odometerKm: odo,
    timestamp: DateTime(2026, 9, day),
  );
}

void main() {
  group('FillUpLog.build', () {
    test('returns entries newest first', () {
      final log = FillUpLog.build([
        fill(282.05, 9066, 26, liters: 3.663),
        fill(755.47, 9129, 27, liters: 9.213),
      ]);
      expect(log.entries.map((e) => e.fillUp.odometerKm), [9129, 9066]);
    });

    test('first fill-up has no distance or efficiency', () {
      final log = FillUpLog.build([fill(500, 9000, 1, liters: 8)]);
      final only = log.entries.single;
      expect(only.kmSincePrevious, isNull);
      expect(only.kmPerLiter, isNull);
      expect(only.costPerKm, isNull);
    });

    test('km/L divides distance since the previous fill by liters now', () {
      final log = FillUpLog.build([
        fill(282.05, 9066, 26, liters: 3.663),
        fill(755.47, 9129, 27, liters: 9.213),
      ]);
      final latest = log.entries.first;
      expect(latest.kmSincePrevious, 63);
      expect(latest.kmPerLiter, closeTo(6.84, 0.01));
      expect(latest.costPerKm, closeTo(11.99, 0.01));
    });

    test('efficiency is null when liters were not entered', () {
      final log = FillUpLog.build([fill(500, 9000, 1), fill(600, 9100, 2)]);
      expect(log.entries.first.kmSincePrevious, 100);
      expect(log.entries.first.kmPerLiter, isNull);
      expect(log.entries.first.costPerKm, 6);
    });

    test('ignores a non-increasing odometer instead of going negative', () {
      final log = FillUpLog.build([fill(500, 9100, 1), fill(600, 9000, 2)]);
      expect(log.entries.first.kmSincePrevious, isNull);
    });

    test('averages km/L across entries and flags the better ones', () {
      final log = FillUpLog.build([
        fill(300, 9000, 1, liters: 4),
        fill(400, 9040, 2, liters: 4), // 10 km/L
        fill(500, 9060, 3, liters: 4), // 5 km/L
      ]);
      expect(log.averageKmPerLiter, closeTo(7.5, 0.001));
      expect(log.entries[1].isAboveAverage, isTrue);
      expect(log.entries[0].isAboveAverage, isFalse);
    });
  });
}
