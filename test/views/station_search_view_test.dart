import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/services/recent_searches.dart';
import 'package:gasolinahan/viewmodels/dashboard_viewmodel.dart';
import 'package:gasolinahan/views/station_search_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

StationModel station(String name, String brand, double lat, double lng) =>
    StationModel.fromMap({
      'name': name,
      'brand': brand,
      'address': 'Iligan',
      'latitude': lat,
      'longitude': lng,
      'regularPrice': 60.0,
      if (name.startsWith('Shell')) 'amenities': {'restroom': true},
    }, name);

// The user stands at the plaza; Saray is closer than Tibanga.
final _stations = [
  station('Shell Tibanga', 'Shell', 8.2400, 124.2500),
  station('Petron Plaza', 'Petron', 8.2280, 124.2440),
  station('Seaoil Saray', 'Seaoil', 8.2340, 124.2450),
];

Future<ValueNotifier<StationModel?>> pumpSearch(
  WidgetTester tester, {
  bool withFix = true,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final picked = ValueNotifier<StationModel?>(null);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              picked.value = await showStationSearch(
                context,
                stations: _stations,
                fuelType: FuelType.regular,
                userLat: withFix ? 8.2281 : null,
                userLng: withFix ? 124.2441 : null,
                recent: RecentSearches(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
}

/// Station names in the order the list shows them.
List<String> listedNames(WidgetTester tester) {
  final names = _stations.map((s) => s.name).toSet();
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where(names.contains)
      .toList();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists every station nearest first with its distance', (
    tester,
  ) async {
    await pumpSearch(tester);
    expect(find.text('Nearest to you'), findsOneWidget);
    expect(listedNames(tester), [
      'Petron Plaza',
      'Seaoil Saray',
      'Shell Tibanga',
    ]);
    expect(find.textContaining('m · Iligan'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing narrows the list and a brand chip fills the query', (
    tester,
  ) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'shell');
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Shell Tibanga']);
    expect(find.text('1 result'), findsOneWidget);

    // Brand chips follow the amenity chips, off the right edge at first.
    final chipRow = find.byType(ListView).first;
    await tester.dragUntilVisible(
      find.bySemanticsLabel('Petron'),
      chipRow,
      const Offset(-120, 0),
    );
    await tester.tap(find.bySemanticsLabel('Petron'));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Petron Plaza']);

    // Tapping the chip again clears it.
    await tester.tap(find.bySemanticsLabel('Petron'));
    await tester.pumpAndSettle();
    expect(listedNames(tester).length, 3);
  });

  testWidgets('tapping a station returns it and remembers the search', (
    tester,
  ) async {
    final picked = await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'saray');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seaoil Saray'));
    await tester.pumpAndSettle();
    expect(picked.value?.name, 'Seaoil Saray');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('saray'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove saray from recent searches'));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsNothing);
  });

  testWidgets('without a fix it lists all stations and the back arrow '
      'returns nothing', (tester) async {
    final picked = await pumpSearch(tester, withFix: false);
    expect(find.text('All stations'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(picked.value, isNull);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an amenity chip keeps only stations that list it', (
    tester,
  ) async {
    await pumpSearch(tester);
    await tester.tap(find.bySemanticsLabel('Restroom'));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Shell Tibanga']);
    expect(find.text('1 result'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Restroom'));
    await tester.pumpAndSettle();
    expect(listedNames(tester).length, 3);
  });
}
