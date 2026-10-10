import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/station_tracker_card.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/station_summary.dart';

FillUp _fill(double spent, double odo, int day) => FillUp(
  stationId: 'shell-1',
  stationName: 'Shell Ayala',
  brand: 'Shell',
  fuelType: 'regular',
  amountSpent: spent,
  odometerKm: odo,
  timestamp: DateTime(2026, 1, day),
);

void main() {
  testWidgets('shows station name, totals, visits and km driven', (
    tester,
  ) async {
    final summary = StationSummary.summarize([
      _fill(1000, 10000, 1),
      _fill(1500, 10500, 5),
    ]).single;
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StationTrackerCard(
            summary: summary,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Shell Ayala'), findsOneWidget);
    expect(find.text('₱2,500'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('500 km'), findsOneWidget);
    expect(find.text('₱2.00/km'), findsOneWidget);

    await tester.tap(find.byType(StationTrackerCard));
    expect(tapped, isTrue);
  });
}
