import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/fill_up_log_card.dart';
import 'package:gasolinahan/models/fill_up_log.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/views/fill_up_detail_sheet.dart';

FillUp fill(double spent, double odo, int day, double liters) => FillUp(
  id: day,
  stationId: 's1',
  stationName: 'SeaOil Mayapa',
  brand: 'SeaOil',
  fuelType: 'diesel',
  productName: 'Turbo Diesel',
  amountSpent: spent,
  liters: liters,
  pricePerLiter: spent / liters,
  odometerKm: odo,
  timestamp: DateTime(2026, 9, day),
  notes: day == 27 ? 'Pricelocq discount' : '',
);

final _log = FillUpLog.build([
  fill(282.05, 9066, 26, 3.663),
  fill(755.47, 9129, 27, 9.213),
]);

/// Pumps a button that opens the sheet; [result] holds what it returned.
Future<ValueNotifier<FillUpAction?>> pumpOpener(
  WidgetTester tester,
  FillUpLogEntry entry,
) async {
  final result = ValueNotifier<FillUpAction?>(null);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result.value = await showFillUpDetail(context, entry),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows the fill-up read-only with every field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FillUpDetailSheet(entry: _log.entries.first)),
      ),
    );
    expect(find.text('SeaOil Mayapa'), findsOneWidget);
    expect(find.text('Turbo Diesel'), findsOneWidget);
    expect(find.text('Sep 27, 2026'), findsOneWidget);
    expect(find.text('₱755.47'), findsOneWidget);
    expect(find.textContaining('9.213 L'), findsOneWidget);
    expect(find.text('9,129 km'), findsOneWidget);
    expect(find.text('+63 km'), findsOneWidget);
    expect(find.text('6.84 km/L'), findsOneWidget);
    expect(find.text('Pricelocq discount'), findsOneWidget);
    expect(find.text('Edit fill-up'), findsOneWidget);
    expect(find.text('Delete fill-up'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first fill-up explains what the next one unlocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FillUpDetailSheet(entry: _log.entries.last)),
      ),
    );
    expect(find.text('First fill-up'), findsOneWidget);
    expect(find.text('Needs a next fill-up'), findsOneWidget);
    expect(find.textContaining('km/L'), findsNothing);
  });

  testWidgets('Edit hands back the edit action', (tester) async {
    final result = await pumpOpener(tester, _log.entries.first);
    await tester.tap(find.text('Edit fill-up'));
    await tester.pumpAndSettle();
    expect(result.value, FillUpAction.edit);
    expect(find.text('Edit fill-up'), findsNothing); // sheet closed
  });

  testWidgets('Delete hands back the delete action', (tester) async {
    final result = await pumpOpener(tester, _log.entries.first);
    await tester.tap(find.text('Delete fill-up'));
    await tester.pumpAndSettle();
    expect(result.value, FillUpAction.delete);
  });

  testWidgets('closing without choosing returns nothing', (tester) async {
    final result = await pumpOpener(tester, _log.entries.first);
    expect(find.text('₱755.47'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result.value, isNull);
    expect(find.text('₱755.47'), findsNothing);
  });
}
