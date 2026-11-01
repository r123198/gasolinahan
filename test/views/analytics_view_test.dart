import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/services/fill_up_service.dart';
import 'package:gasolinahan/viewmodels/fill_up_viewmodel.dart';
import 'package:gasolinahan/views/analytics_view.dart';
import 'package:provider/provider.dart';

class _FakeService extends FillUpService {
  final List<FillUp> rows;
  _FakeService(this.rows);

  @override
  Future<List<FillUp>> getAll({String? ownerUid}) async => rows;
}

FillUp fill(String brand, double odo, int day, {int month = 9}) => FillUp(
  stationId: brand,
  stationName: brand,
  brand: brand,
  fuelType: 'regular',
  amountSpent: 800,
  // 10 L every time: Petron tanks cover 100 km, Shell tanks 80 km.
  liters: 10,
  odometerKm: odo,
  timestamp: DateTime(2026, month, day),
);

final _now = DateTime(2026, 9, 20);

Future<void> pumpAnalytics(WidgetTester tester, List<FillUp> rows) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final vm = FillUpViewModel(service: _FakeService(rows));
  await vm.load();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: vm,
      child: MaterialApp(home: AnalyticsView(now: _now)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

final _history = [
  fill('Petron', 900, 20, month: 8),
  fill('Petron', 1000, 1), // 100 km on August's Petron fuel
  fill('Shell', 1100, 5),
  fill('Petron', 1180, 9),
  fill('Shell', 1280, 13),
  fill('Petron', 1360, 17),
];

void main() {
  testWidgets('leads with this month\'s spend, distance and efficiency', (
    tester,
  ) async {
    await pumpAnalytics(tester, _history);
    expect(find.text('Spent on fuel this month'), findsOneWidget);
    expect(find.text('₱4,000.00'), findsOneWidget); // 5 fill-ups × ₱800
    expect(find.text('5 fill-ups · vs last month'), findsOneWidget);
    expect(find.text('460 km'), findsOneWidget); // 100+100+80+100+80
    // Last tank (Shell, 80 km on 10 L) is below the 9.2 km/L average.
    expect(find.text('Burning more than usual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('range chips switch the headline to all time', (tester) async {
    await pumpAnalytics(tester, _history);
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('Spent on fuel, all time'), findsOneWidget);
    expect(find.text('₱4,800.00'), findsOneWidget); // 6 fill-ups
    expect(find.text('6 fill-ups'), findsOneWidget); // no comparison
  });

  testWidgets('groups the report under Spending, Driving, Efficiency, '
      'Prices and Records', (tester) async {
    await pumpAnalytics(tester, _history);
    for (final heading in ['Spending', 'Driving', 'Efficiency', 'Records']) {
      await scrollTo(tester, find.text(heading));
      expect(find.text(heading), findsOneWidget);
    }
    await scrollTo(tester, find.textContaining('Petron goes'));
    expect(
      find.text('Petron goes 25% further per liter than Shell in your car.'),
      findsOneWidget,
    );
    await scrollTo(tester, find.text('Longest without refilling'));
    expect(find.text('Longest without refilling'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spells out each formula on its own line', (tester) async {
    await pumpAnalytics(tester, _history);
    await scrollTo(tester, find.text('How these are calculated'));
    await tester.tap(find.text('How these are calculated'));
    await tester.pumpAndSettle();
    expect(find.text('Km per liter'), findsOneWidget);
    expect(
      find.text('= km since last fill-up ÷ liters bought now'),
      findsOneWidget,
    );
    expect(find.text('= km per day × 30 × cost per km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains what unlocks with only one fill-up', (tester) async {
    await pumpAnalytics(tester, [fill('Shell', 1000, 1)]);
    expect(find.text('One more fill-up to go'), findsOneWidget);
  });
}
