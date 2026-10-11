import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/report_price_row.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/ui/app_theme.dart';
import 'package:gasolinahan/views/report_form_parts.dart';

StationModel station(String id, String name, String brand) =>
    StationModel.fromMap({
      'name': name,
      'brand': brand,
      'latitude': 14.5,
      'longitude': 121.0,
    }, id);

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('station cards select on tap and announce distance', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    StationModel? picked;
    await tester.pumpWidget(
      host(
        ReportStationPicker(
          stations: [station('a', 'Petron Mayapa', 'Petron')],
          distances: const {'a': 120},
          selected: null,
          emptyMessage: 'none',
          onSelect: (s) => picked = s,
          onClear: () {},
        ),
      ),
    );
    final card = find.bySemanticsLabel(RegExp('Petron Mayapa, .* away'));
    expect(card, findsOneWidget);
    await tester.tap(card);
    expect(picked?.id, 'a');
    handle.dispose();
  });

  testWidgets('a far-away pick warns and offers Change', (tester) async {
    var cleared = 0;
    await tester.pumpWidget(
      host(
        ReportStationPicker(
          stations: const [],
          distances: const {'a': 900},
          selected: station('a', 'Shell EDSA', 'Shell'),
          emptyMessage: 'none',
          onSelect: (_) {},
          onClear: () => cleared++,
        ),
      ),
    );
    expect(find.textContaining('Reports work best'), findsOneWidget);
    await tester.tap(find.text('Change'));
    expect(cleared, 1);
  });

  testWidgets('price row shows the grade in its pump colour and errors', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        ReportPriceRow(
          grade: 'Diesel',
          product: 'Turbo Diesel',
          color: AppColors.fuelDiesel,
          controller: controller,
          action: TextInputAction.done,
          onChanged: () {},
          error: 'Should be ₱30–₱150',
        ),
      ),
    );
    final grade = tester.widget<Text>(find.text('Diesel'));
    expect(grade.style?.color, AppColors.fuelDiesel);
    expect(find.text('Turbo Diesel'), findsOneWidget);
    expect(find.text('Should be ₱30–₱150'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '62.5.0');
    expect(controller.text, isNot('62.5.0'));
  });
}
