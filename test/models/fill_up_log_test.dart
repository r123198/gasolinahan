import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_log.dart';
import 'package:gasolinahan/models/fill_up_model.dart';

FillUp fill(
  double spent,
  double odo,
  int day, {
  double? liters,
  int? id,
  String fuel = 'regular',
  int month = 9,
}) {
  return FillUp(
    id: id,
    stationId: 's',
    stationName: 'SeaOil Mayapa',
    brand: 'SeaOil',
    fuelType: fuel,
    amountSpent: spent,
    liters: liters,
    odometerKm: odo,
    timestamp: DateTime(2026, month, day),
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

    test('one reading has nothing to compare, so no better/worse flag', () {
      final log = FillUpLog.build([
        fill(300, 9000, 1, liters: 4),
        fill(400, 9040, 2, liters: 4),
      ]);
      expect(log.entries.first.isAboveAverage, isNull);
      expect(log.entries.first.isCheaperPerKm, isNull);
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

  group('comparisons', () {
    test('price delta compares with your other fills of the same fuel', () {
      final log = FillUpLog.build([
        fill(800, 9000, 1, liters: 10), // ₱80/L
        fill(840, 9100, 2, liters: 10), // pricey/L
        fill(1000, 9200, 3, liters: 10, fuel: 'diesel'), // other fuel
        fill(820, 9300, 4, liters: 10), // ₱82/L, avg of others = 82
      ]);
      expect(log.entries.first.priceDelta, closeTo(0, 0.001));
      final pricey = log.entries.firstWhere((e) => e.fillUp.odometerKm == 9100);
      expect(pricey.priceDelta, closeTo(3, 0.001)); // vs (80 + 82) / 2
    });

    test('no price delta without another fill of that fuel', () {
      final log = FillUpLog.build([fill(800, 9000, 1, liters: 10)]);
      expect(log.entries.single.priceDelta, isNull);
    });

    test('flags cheaper-per-km tanks against the average', () {
      final log = FillUpLog.build([
        fill(500, 9000, 1),
        fill(500, 9100, 2), // ₱5/km
        fill(500, 9150, 3), // ₱10/km
      ]);
      expect(log.averageCostPerKm, closeTo(7.5, 0.001));
      expect(log.entries[1].isCheaperPerKm, isTrue);
      expect(log.entries[0].isCheaperPerKm, isFalse);
    });

    test('sums spending for the current month only', () {
      final log = FillUpLog.build([
        fill(500, 9000, 28, month: 9),
        fill(700, 9100, 2, month: 10),
        fill(300, 9200, 5, month: 10),
      ]);
      final month = log.monthSummary(DateTime(2026, 10, 10));
      expect(month.spent, 1000);
      expect(month.fillUps, 2);
    });
  });
}
