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

FillUp fill(String brand, double odo, int day) => FillUp(
  stationId: brand,
  stationName: brand,
  brand: brand,
  fuelType: 'regular',
  amountSpent: 800,
  // 10 L every time: Petron tanks cover 100 km, Shell tanks 80 km.
  liters: 10,
  odometerKm: odo,
  timestamp: DateTime(2026, 9, day),
);

Future<void> pumpAnalytics(WidgetTester tester, List<FillUp> rows) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final vm = FillUpViewModel(service: _FakeService(rows));
  await vm.load();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: vm,
      child: const MaterialApp(home: AnalyticsView()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the projection and the best brand at phone width', (
    tester,
  ) async {
    await pumpAnalytics(tester, [
      fill('Petron', 1000, 1),
      fill('Shell', 1100, 5),
      fill('Petron', 1180, 9),
      fill('Shell', 1280, 13),
      fill('Petron', 1360, 17),
    ]);
    expect(find.text('A month of fuel at your pace'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Petron goes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Petron goes 25% further per liter than Shell in your car.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Longest without refilling'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Longest without refilling'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains what unlocks with only one fill-up', (tester) async {
    await pumpAnalytics(tester, [fill('Shell', 1000, 1)]);
    expect(find.text('One more fill-up to go'), findsOneWidget);
  });
}
