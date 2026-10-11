import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/brand_registry.dart';
import 'package:gasolinahan/views/fill_up_form_parts.dart';

void main() {
  testWidgets('one tap on a logo picks that brand; Other is last', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    BrandInfo? picked;
    var other = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandChips(
            brands: BrandRegistry.brands,
            selected: BrandRegistry.findByName('Shell'),
            isOtherSelected: false,
            onSelected: (b) => picked = b,
            onOther: () => other++,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Shell')),
      matchesSemantics(
        label: 'Shell',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Petron'));
    expect(picked?.name, 'Petron');

    await tester.dragUntilVisible(
      find.bySemanticsLabel('Other'),
      find.byType(ListView),
      const Offset(-200, 0),
    );
    await tester.tap(find.bySemanticsLabel('Other'));
    expect(other, 1);
    handle.dispose();
  });
}
