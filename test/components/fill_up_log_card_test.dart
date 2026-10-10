import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/fill_up_log_card.dart';
import 'package:gasolinahan/models/fill_up_log.dart';
import 'package:gasolinahan/models/fill_up_model.dart';

FillUp fill(
  double spent,
  double odo,
  int day,
  double liters, {
  String notes = '',
}) => FillUp(
  id: day,
  stationId: 's1',
  stationName: 'SeaOil Mayapa',
  brand: 'SeaOil',
  fuelType: 'regular',
  amountSpent: spent,
  liters: liters,
  pricePerLiter: spent / liters,
  odometerKm: odo,
  timestamp: DateTime(2026, 9, day),
  notes: notes,
);

Future<void> pump(
  WidgetTester tester,
  FillUpLogEntry entry, {
  ValueChanged<FillUpAction>? onAction,
  VoidCallback? onStationTap,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: FillUpLogCard(
          entry: entry,
          onAction: onAction ?? (_) {},
          onStationTap: onStationTap ?? () {},
        ),
      ),
    ),
  ),
);

void main() {
  final log = FillUpLog.build([
    fill(282.05, 9066, 26, 3.663),
    fill(755.47, 9129, 27, 9.213, notes: 'Pricelocq discount'),
  ]);

  testWidgets('shows the fields from the fill-up log design', (tester) async {
    await pump(tester, log.entries.first);
    expect(find.text('Sep 27, 2026'), findsOneWidget);
    expect(find.text('₱755.47'), findsOneWidget);
    expect(find.text('9,129 km'), findsOneWidget);
    expect(find.text('+63 km'), findsOneWidget);
    expect(find.textContaining('9.213 L'), findsOneWidget);
    expect(find.textContaining('₱82.00/L'), findsOneWidget);
    expect(find.textContaining('6.84 km/L'), findsOneWidget);
    expect(find.text('SeaOil Mayapa'), findsOneWidget);
    expect(find.text('Pricelocq discount'), findsOneWidget);
  });

  testWidgets('first fill-up hides distance and efficiency', (tester) async {
    await pump(tester, log.entries.last);
    expect(find.textContaining('km/L'), findsNothing);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('tapping the card opens edit; the station row opens history', (
    tester,
  ) async {
    FillUpAction? action;
    var stationTaps = 0;
    await pump(
      tester,
      log.entries.first,
      onAction: (a) => action = a,
      onStationTap: () => stationTaps++,
    );
    await tester.tap(find.text('₱755.47'));
    expect(action, FillUpAction.edit);
    await tester.tap(find.text('SeaOil Mayapa'));
    expect(stationTaps, 1);
  });

  testWidgets('menu offers edit and delete', (tester) async {
    FillUpAction? action;
    await pump(tester, log.entries.first, onAction: (a) => action = a);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(action, FillUpAction.delete);
  });
}
