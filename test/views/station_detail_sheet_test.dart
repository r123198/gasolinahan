import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/price_freshness.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/views/station_detail_sheet.dart';

StationModel station(DateTime updated) => StationModel(
  id: 's1',
  name: 'Unknown Station',
  brand: 'Petron',
  address: 'Mayapa, Calamba',
  latitude: 14.2,
  longitude: 121.1,
  regularPrice: 59.8,
  premiumPrice: 61.55,
  dieselPrice: 51.2,
  lastUpdated: updated,
);

Future<int> open(WidgetTester tester, StationModel s) async {
  var reports = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showStationDetailSheet(
              context,
              station: s,
              onReport: () => reports++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return reports;
}

void main() {
  testWidgets('a report from before Tuesday asks for new prices', (
    tester,
  ) async {
    final beforeChange = latestPriceChange(
      DateTime.now(),
    ).subtract(const Duration(days: 2));
    await open(tester, station(beforeChange));
    expect(find.text('Petron station'), findsOneWidget);
    expect(find.text('Prices may have changed'), findsOneWidget);
    expect(find.text('Report new prices'), findsOneWidget);
  });

  testWidgets('this week\'s prices hide the update button', (tester) async {
    await open(tester, station(DateTime.now()));
    expect(find.text('Report new prices'), findsNothing);
    expect(find.textContaining("This week's prices"), findsOneWidget);
  });
}
