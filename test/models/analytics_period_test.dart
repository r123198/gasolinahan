import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/analytics_period.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/fuel_analytics.dart';

FillUp fill(
  double odo,
  DateTime at, {
  double spent = 800,
  double liters = 10,
}) => FillUp(
  stationId: 'petron',
  stationName: 'Petron Station',
  brand: 'Petron',
  fuelType: 'regular',
  amountSpent: spent,
  liters: liters,
  pricePerLiter: spent / liters,
  odometerKm: odo,
  timestamp: at,
);

void main() {
  final now = DateTime(2026, 10, 20);
  // August: one fill-up. September: two refills covering 200 km on 20 L.
  // October: one refill covering 80 km on 10 L for ₱900.
  final history = [
    fill(1000, DateTime(2026, 8, 20)),
    fill(1100, DateTime(2026, 9, 2)), // 100 km, 10 L
    fill(1200, DateTime(2026, 9, 16)), // 100 km, 10 L
    fill(1280, DateTime(2026, 10, 5), spent: 900), // 80 km, 10 L
  ];
  final analytics = FuelAnalytics.compute(history, now: now);

  test('this month sums its fill-ups and the tanks measured in it', () {
    final c = PeriodComparison.compute(
      analytics,
      AnalyticsRange.month,
      now: now,
    );
    expect(c.current.spent, 900);
    expect(c.current.fillUps, 1);
    expect(c.current.km, 80);
    expect(c.current.kmPerLiter, closeTo(8, 0.001));
    expect(c.current.costPerKm, closeTo(900 / 80, 0.001));
    expect(c.previous?.spent, 1600);
    expect(c.previous?.km, 200);
    expect(c.previous?.kmPerLiter, closeTo(10, 0.001));
  });

  test('compares with the stretch before as a fraction', () {
    final c = PeriodComparison.compute(
      analytics,
      AnalyticsRange.month,
      now: now,
    );
    expect(c.spentChange, closeTo((900 - 1600) / 1600, 0.001));
    expect(c.kmChange, closeTo((80 - 200) / 200, 0.001));
    expect(c.efficiencyChange, closeTo((8 - 10) / 10, 0.001));
  });

  test('three months rolls up Aug–Oct against May–Jul', () {
    final c = PeriodComparison.compute(
      analytics,
      AnalyticsRange.quarter,
      now: now,
    );
    expect(c.current.start, DateTime(2026, 8));
    expect(c.current.end, DateTime(2026, 11));
    expect(c.current.spent, 800 * 3 + 900);
    expect(c.current.km, 280);
    expect(c.previous?.start, DateTime(2026, 5));
    expect(c.previous?.spent, 0);
    expect(c.spentChange, isNull); // nothing to compare with
  });

  test('all time has totals and no comparison', () {
    final c = PeriodComparison.compute(analytics, AnalyticsRange.all, now: now);
    expect(c.previous, isNull);
    expect(c.current.spent, 800 * 3 + 900);
    expect(c.current.km, 280);
    expect(c.current.kmPerLiter, closeTo(280 / 30, 0.001));
    expect(c.spentChange, isNull);
  });

  test('an empty month has zeros rather than nulls for spend and km', () {
    final c = PeriodComparison.compute(
      FuelAnalytics.compute(const [], now: now),
      AnalyticsRange.month,
      now: now,
    );
    expect(c.current.spent, 0);
    expect(c.current.km, 0);
    expect(c.current.kmPerLiter, isNull);
    expect(c.current.costPerKm, isNull);
  });

  group('monthly km and verdict', () {
    test('monthly totals carry km driven and fill-up counts', () {
      final sep = analytics.monthlySpend.firstWhere((m) => m.month.month == 9);
      final oct = analytics.monthlySpend.firstWhere((m) => m.month.month == 10);
      expect(sep.km, 200);
      expect(sep.fillUps, 2);
      expect(oct.km, 80);
      expect(oct.fillUps, 1);
    });

    test('the latest tank is judged against the average', () {
      // Tanks: 10, 10, 8 km/L → average 9.33; latest is 14% below.
      expect(analytics.latestTank?.kmPerLiter, closeTo(8, 0.001));
      expect(analytics.latestEfficiencyChange, closeTo(-0.1429, 0.001));
      expect(analytics.verdict, EfficiencyVerdict.wasteful);
    });

    test('a tank near the average is "usual", a better one "efficient"', () {
      final usual = FuelAnalytics.compute([
        fill(1000, DateTime(2026, 9, 1)),
        fill(1100, DateTime(2026, 9, 10)),
        fill(1202, DateTime(2026, 9, 20)),
      ], now: now);
      expect(usual.verdict, EfficiencyVerdict.usual);

      final efficient = FuelAnalytics.compute([
        fill(1000, DateTime(2026, 9, 1)),
        fill(1080, DateTime(2026, 9, 10)),
        fill(1200, DateTime(2026, 9, 20)),
      ], now: now);
      expect(efficient.verdict, EfficiencyVerdict.efficient);
    });

    test('needs two measured tanks before judging', () {
      final one = FuelAnalytics.compute([
        fill(1000, DateTime(2026, 9, 1)),
        fill(1100, DateTime(2026, 9, 10)),
      ], now: now);
      expect(one.latestEfficiencyChange, isNull);
      expect(one.verdict, isNull);
    });
  });
}
