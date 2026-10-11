import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/fuel_insights.dart';
import 'package:gasolinahan/models/trip_model.dart';

FillUp fill(double spent, double odo, DateTime at, {double? liters}) => FillUp(
  stationId: 's',
  stationName: 'S',
  brand: 'Shell',
  fuelType: 'regular',
  amountSpent: spent,
  liters: liters,
  odometerKm: odo,
  timestamp: at,
);

Trip trip(DateTime at, double km) => Trip(
  startedAt: at,
  endedAt: at.add(const Duration(minutes: 20)),
  distanceMeters: km * 1000,
);

final d1 = DateTime(2026, 1, 1);
final d5 = DateTime(2026, 1, 5);
final d10 = DateTime(2026, 1, 10);

void main() {
  group('FuelInsights.compute', () {
    test('has nothing to say without fill-ups', () {
      final i = FuelInsights.compute(fillUps: const [], trips: const []);
      expect(i.lastFillAt, isNull);
      expect(i.kmSinceLastFill, isNull);
      expect(i.costPerKm, isNull);
    });

    test('counts only trips after the last fill-up', () {
      final i = FuelInsights.compute(
        fillUps: [fill(1000, 10000, d5)],
        trips: [trip(d1, 50), trip(DateTime(2026, 1, 6), 30), trip(d10, 20)],
      );
      expect(i.kmSinceLastFill, 50);
    });

    test('typical refill distance is the average gap between odometers', () {
      final i = FuelInsights.compute(
        fillUps: [
          fill(1000, 10000, d1),
          fill(1000, 10400, d5),
          fill(1000, 10900, d10),
        ],
        trips: const [],
      );
      expect(i.typicalRefillKm, 450);
    });

    test('estimates distance left from the typical refill distance', () {
      final i = FuelInsights.compute(
        fillUps: [
          fill(1000, 10000, d1),
          fill(1000, 10400, d5),
          fill(1000, 10800, DateTime(2026, 1, 8)),
        ],
        trips: [trip(DateTime(2026, 1, 9), 150)],
      );
      expect(i.typicalRefillKm, 400);
      expect(i.estimatedKmLeft, 250);
      expect(i.tankUsedFraction, closeTo(0.375, 0.001));
    });

    test('estimated distance left never goes below zero', () {
      final i = FuelInsights.compute(
        fillUps: [fill(1000, 10000, d1), fill(1000, 10400, d5)],
        trips: [trip(d10, 900)],
      );
      expect(i.estimatedKmLeft, 0);
      expect(i.tankUsedFraction, 1);
    });

    test('km per liter uses only fills that have liters and a next fill', () {
      final i = FuelInsights.compute(
        fillUps: [
          fill(1000, 10000, d1, liters: 20),
          fill(1000, 10400, d5, liters: 20),
          fill(1000, 10800, d10, liters: 20),
        ],
        trips: const [],
      );
      expect(i.kmPerLiter, 20); // 800 km over the first two 20 L fills
    });

    test('typical liters averages the fills that have liters', () {
      final i = FuelInsights.compute(
        fillUps: [
          fill(1000, 10000, d1, liters: 20),
          fill(1000, 10400, d5, liters: 10),
          fill(1000, 10800, d10),
        ],
        trips: const [],
      );
      expect(i.typicalLiters, 15);
    });

    test('cost per km spreads spend over distance actually driven', () {
      final i = FuelInsights.compute(
        fillUps: [fill(1000, 10000, d1), fill(800, 10400, d5)],
        trips: const [],
      );
      expect(i.costPerKm, 2.0); // refilling 800 pesos after 400 km
    });
  });

  group('evaluateDetour', () {
    test('recommends the trip when savings beat the extra driving cost', () {
      final v = evaluateDetour(
        extraKm: 4,
        costPerKm: 2.5,
        priceHere: 60,
        priceThere: 58,
        liters: 20,
      );
      expect(v.savings, closeTo(40, 0.001));
      expect(v.detourCost, closeTo(10, 0.001));
      expect(v.net, closeTo(30, 0.001));
      expect(v.worthIt, isTrue);
    });

    test('advises against a detour that costs more than it saves', () {
      final v = evaluateDetour(
        extraKm: 12,
        costPerKm: 3,
        priceHere: 60,
        priceThere: 59.5,
        liters: 10,
      );
      expect(v.worthIt, isFalse);
      expect(v.net, lessThan(0));
    });

    test('a more expensive station is never worth it', () {
      final v = evaluateDetour(
        extraKm: 0,
        costPerKm: 2.5,
        priceHere: 58,
        priceThere: 60,
        liters: 20,
      );
      expect(v.worthIt, isFalse);
    });
  });
}
