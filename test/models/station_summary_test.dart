import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/station_summary.dart';

FillUp fill(
  String station,
  double spent,
  double odo,
  int day, {
  double? liters,
}) {
  return FillUp(
    stationId: station,
    stationName: station.toUpperCase(),
    brand: 'Shell',
    fuelType: 'regular',
    amountSpent: spent,
    liters: liters,
    odometerKm: odo,
    timestamp: DateTime(2026, 1, day),
  );
}

void main() {
  group('StationSummary.summarize', () {
    test('returns empty list when there are no fill-ups', () {
      expect(StationSummary.summarize(const []), isEmpty);
    });

    test('attributes km to the station where the tank was filled', () {
      final summaries = StationSummary.summarize([
        fill('a', 1000, 10000, 1),
        fill('b', 1200, 10400, 5),
        fill('a', 1100, 10900, 10),
      ]);

      final a = summaries.firstWhere((s) => s.key == 'a');
      final b = summaries.firstWhere((s) => s.key == 'b');
      expect(a.visits, 2);
      expect(a.totalSpent, 2100);
      expect(a.kmDriven, 400); // 10000 -> 10400; latest fill has no next
      expect(b.kmDriven, 500); // 10400 -> 10900
    });

    test('orders by most recent visit first', () {
      final summaries = StationSummary.summarize([
        fill('a', 1000, 10000, 1),
        fill('b', 1200, 10400, 5),
      ]);
      expect(summaries.map((s) => s.key), ['b', 'a']);
    });

    test('computes cost per km from fills with a known distance only', () {
      final summaries = StationSummary.summarize([
        fill('a', 1000, 10000, 1),
        fill('a', 800, 10400, 5),
      ]);
      final a = summaries.single;
      expect(a.kmDriven, 400);
      expect(a.spentWithKnownKm, 1000);
      expect(a.costPerKm, 2.5);
    });

    test('has no cost per km before a second fill-up exists', () {
      final a = StationSummary.summarize([fill('a', 1000, 10000, 1)]).single;
      expect(a.kmDriven, 0);
      expect(a.costPerKm, isNull);
    });

    test('ignores non-increasing odometer readings', () {
      final a = StationSummary.summarize([
        fill('a', 1000, 10000, 1),
        fill('a', 900, 9000, 5),
      ]).single;
      expect(a.kmDriven, 0);
    });

    test('sums liters that were recorded', () {
      final a = StationSummary.summarize([
        fill('a', 1000, 10000, 1, liters: 16),
        fill('a', 900, 10400, 5),
      ]).single;
      expect(a.totalLiters, 16);
    });
  });

  group('StationSummary.historyFor', () {
    test('returns one station newest first', () {
      final history = StationSummary.historyFor('a', [
        fill('a', 1, 100, 1),
        fill('b', 1, 200, 2),
        fill('a', 1, 300, 3),
      ]);
      expect(history.map((f) => f.odometerKm), [300, 100]);
    });
  });

  group('TrackerTotals', () {
    test('is zero when empty', () {
      final t = TrackerTotals.from(const []);
      expect(t.fillUps, 0);
      expect(t.costPerKm, isNull);
    });

    test('spans lowest to highest odometer, minus the first tank', () {
      final t = TrackerTotals.from([
        fill('a', 1000, 10000, 1),
        fill('b', 1000, 10500, 5),
      ]);
      expect(t.totalSpent, 2000);
      expect(t.totalKm, 500);
      // The first ₱1000 was burned before any logged km: 1000 / 500.
      expect(t.costPerKm, 2);
    });
  });
}
