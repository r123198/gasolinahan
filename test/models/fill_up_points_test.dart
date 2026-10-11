import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/fill_up_points.dart';
import 'package:gasolinahan/models/points_rules.dart';

FillUp fill(
  DateTime at, {
  double odo = 1000,
  int points = 2,
  double? price = 60,
  String? product = 'XCS',
}) => FillUp(
  stationId: 's',
  stationName: 'Petron',
  brand: 'Petron',
  fuelType: 'regular',
  amountSpent: 600,
  pricePerLiter: price,
  productName: product,
  odometerKm: odo,
  timestamp: at,
  pointsAwarded: points,
);

void main() {
  final now = DateTime(2026, 10, 11, 9);

  test('the very first fill-up is flagged for its head start', () {
    final ctx = fillUpPointsContext(newFill: fill(now), history: const []);
    expect(ctx.isFirstFillUp, isTrue);
    expect(pointsForFillUp(ctx).points, 4);
  });

  test('complete means price per liter and product are set', () {
    expect(
      fillUpPointsContext(newFill: fill(now), history: const []).isComplete,
      isTrue,
    );
    expect(
      fillUpPointsContext(
        newFill: fill(now, product: null),
        history: const [],
      ).isComplete,
      isFalse,
    );
  });

  test('counts rewarded fill-ups on the same day and in the same month', () {
    final ctx = fillUpPointsContext(
      newFill: fill(now, odo: 1300),
      history: [
        fill(DateTime(2026, 10, 11, 7), odo: 1200),
        fill(DateTime(2026, 10, 3), odo: 1100),
        fill(DateTime(2026, 10, 1), odo: 1050, points: 0),
        fill(DateTime(2026, 9, 28), odo: 1000),
      ],
    );
    expect(ctx.rewardedToday, 1);
    expect(ctx.rewardedThisMonth, 2);
    expect(ctx.fillUpsThisMonth, 3);
    expect(ctx.isFirstFillUp, isFalse);
  });

  test('odometer below the fill-up before it is inconsistent', () {
    final ctx = fillUpPointsContext(
      newFill: fill(now, odo: 900),
      history: [fill(DateTime(2026, 10, 1), odo: 1000)],
    );
    expect(ctx.odometerConsistent, isFalse);
  });
}
