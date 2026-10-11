import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/fuel_analytics.dart';

FillUp fill(
  String brand,
  double odo,
  DateTime at, {
  double spent = 800,
  double liters = 10,
  String fuel = 'regular',
}) => FillUp(
  stationId: brand.toLowerCase(),
  stationName: '$brand Station',
  brand: brand,
  fuelType: fuel,
  amountSpent: spent,
  liters: liters,
  pricePerLiter: spent / liters,
  odometerKm: odo,
  timestamp: at,
);

void main() {
  final now = DateTime(2026, 10, 11);

  test('empty history has no analytics', () {
    final a = FuelAnalytics.compute(const [], now: now);
    expect(a.hasEnoughData, isFalse);
    expect(a.brands, isEmpty);
    expect(a.bestBrand, isNull);
  });

  group('brand performance', () {
    // Petron tanks give 10 km/L, Shell tanks give 8 km/L. A tank's km/L is
    // measured at the NEXT fill-up, so it belongs to the brand filled before.
    final history = [
      fill('Petron', 1000, DateTime(2026, 9, 1)),
      fill('Shell', 1100, DateTime(2026, 9, 5)), // 100 km on Petron fuel
      fill('Petron', 1180, DateTime(2026, 9, 9)), // 80 km on Shell fuel
      fill('Shell', 1280, DateTime(2026, 9, 13)), // 100 km on Petron fuel
      fill('Petron', 1360, DateTime(2026, 9, 17)), // 80 km on Shell fuel
    ];

    test('credits each tank to the brand it was filled with', () {
      final a = FuelAnalytics.compute(history, now: now);
      final petron = a.brands.firstWhere((b) => b.brand == 'Petron');
      final shell = a.brands.firstWhere((b) => b.brand == 'Shell');
      expect(petron.kmPerLiter, closeTo(10, 0.001));
      expect(shell.kmPerLiter, closeTo(8, 0.001));
      expect(petron.tanks, 2);
      expect(shell.tanks, 2);
    });

    test('ranks brands best km/L first and names the best', () {
      final a = FuelAnalytics.compute(history, now: now);
      expect(a.brands.map((b) => b.brand), ['Petron', 'Shell']);
      expect(a.bestBrand?.brand, 'Petron');
      expect(a.bestBrandAdvantage, closeTo(0.25, 0.001)); // 10 vs 8 km/L
    });

    test('needs two tanks before calling a brand the best', () {
      final a = FuelAnalytics.compute(history.take(3).toList(), now: now);
      expect(a.bestBrand, isNull);
    });

    test('reads the brand from the station name when it was not stored', () {
      final a = FuelAnalytics.compute([
        FillUp(
          stationId: '',
          stationName: 'Petron Mayapa',
          brand: '',
          fuelType: 'regular',
          amountSpent: 800,
          liters: 10,
          odometerKm: 1000,
          timestamp: DateTime(2026, 9, 1),
        ),
        fill('Shell', 1100, DateTime(2026, 9, 5)),
      ], now: now);
      expect(a.brands.single.brand, 'Petron');
    });
  });

  group('records', () {
    final history = [
      fill('Shell', 1000, DateTime(2026, 8, 1)),
      fill('Shell', 1300, DateTime(2026, 8, 21), liters: 20), // 15 km/L, 20 d
      fill('Shell', 1400, DateTime(2026, 8, 25), spent: 900), // 10 km/L, 4 d
    ];

    test('finds the longest stretch between fill-ups', () {
      final a = FuelAnalytics.compute(history, now: now);
      expect(a.longestGap?.days, 20);
      expect(a.longestGap?.km, 300);
    });

    test('finds the best and worst tanks', () {
      final a = FuelAnalytics.compute(history, now: now);
      expect(a.bestTank?.kmPerLiter, closeTo(15, 0.001));
      expect(a.worstTank?.kmPerLiter, closeTo(10, 0.001));
    });

    test('finds the cheapest and priciest price per liter', () {
      final a = FuelAnalytics.compute(history, now: now);
      expect(a.cheapestPrice?.pricePerLiter, closeTo(40, 0.001));
      expect(a.priciestPrice?.pricePerLiter, closeTo(90, 0.001));
    });

    test('averages days and km between fill-ups', () {
      final a = FuelAnalytics.compute(history, now: now);
      expect(a.averageDaysBetween, closeTo(12, 0.001));
      expect(a.averageKmBetween, closeTo(200, 0.001));
    });
  });

  group('projection', () {
    test('projects a month of fuel from km per day and cost per km', () {
      final a = FuelAnalytics.compute([
        fill('Shell', 1000, DateTime(2026, 9, 1), spent: 500),
        fill('Shell', 1300, DateTime(2026, 9, 11), spent: 600), // ₱2/km
      ], now: now);
      expect(a.kmPerDay, closeTo(30, 0.001));
      expect(a.projectedMonthlyCost, closeTo(1800, 0.001)); // 30 × 30 × ₱2
    });
  });

  test('monthly spend covers the last six months, zero-filled', () {
    final a = FuelAnalytics.compute([
      fill('Shell', 1000, DateTime(2026, 6, 3), spent: 500),
      fill('Shell', 1100, DateTime(2026, 10, 1), spent: 700),
      fill('Shell', 1200, DateTime(2026, 10, 9), spent: 300),
    ], now: now);
    expect(a.monthlySpend.map((m) => m.month.month), [5, 6, 7, 8, 9, 10]);
    expect(a.monthlySpend.map((m) => m.spent), [0, 500, 0, 0, 0, 1000]);
  });

  test('efficiency trend is chronological, one point per measured tank', () {
    final a = FuelAnalytics.compute([
      fill('Shell', 1000, DateTime(2026, 9, 1)),
      fill('Shell', 1100, DateTime(2026, 9, 5)),
      fill('Shell', 1250, DateTime(2026, 9, 9)),
    ], now: now);
    expect(a.efficiencyTrend.map((p) => p.value), [10, 15]);
  });
}
