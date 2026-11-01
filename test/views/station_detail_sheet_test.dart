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

Future<int> open(
  WidgetTester tester,
  StationModel s, {
  StationDetailsLoader? loadDetails,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
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
              loadDetails: loadDetails,
              now: DateTime(2026, 11, 2), // a Monday
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

  StationModel imported({Map<String, String> hours = const {}}) =>
      StationModel.fromMap({
        'name': 'Soti Fuel Station',
        'brand': '',
        'address': 'Baloi, Lanao del Norte',
        'latitude': 8.16,
        'longitude': 124.2,
        'amenities': {'restroom': true, 'airPump': false, 'open24Hours': false},
        'nearbyStore': '7-Eleven',
        'rating': 4.6,
        'reviewCount': 5,
        'openingHours': hours,
        'phone': hours.isEmpty ? '' : '+63 63 221 0000',
      }, 'soti');

  testWidgets('an imported station lists what it offers and asks for '
      'its first prices', (tester) async {
    await open(tester, imported());
    expect(find.text('No prices reported yet'), findsOneWidget);
    expect(find.text('Report prices'), findsOneWidget);
    expect(find.text('At this station'), findsOneWidget);
    expect(find.bySemanticsLabel('Restroom'), findsOneWidget);
    expect(find.bySemanticsLabel('No air pump'), findsOneWidget);
    expect(find.text('7-Eleven next door'), findsOneWidget);
    expect(find.textContaining('4.6'), findsOneWidget);
    expect(find.textContaining('(5 reviews)'), findsOneWidget);
    expect(find.text('Hours'), findsNothing); // none known yet
    expect(tester.takeException(), isNull);
  });

  testWidgets('hours and phone arrive from the station document', (
    tester,
  ) async {
    final full = imported(
      hours: const {'Monday': '5 AM to 9 PM', 'Tuesday': '5 AM to 9 PM'},
    );
    await open(tester, imported(), loadDetails: (id) async => full);
    expect(find.text('Hours'), findsOneWidget);
    expect(find.text('Monday · 5 AM to 9 PM'), findsOneWidget);
    expect(find.text('+63 63 221 0000'), findsOneWidget);
    await tester.ensureVisible(find.text('All days'));
    await tester.tap(find.text('All days'));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday'), findsOneWidget);
  });
}
