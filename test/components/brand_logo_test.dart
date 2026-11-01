import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/brand_logo.dart';
import 'package:gasolinahan/ui/app_format.dart';

void main() {
  test('initials come from the first and last word', () {
    expect(brandInitials('Blu Energy'), 'BE');
    expect(brandInitials('Velox'), 'V');
    expect(brandInitials('RM C Petrol'), 'RP');
    expect(brandInitials('  '), '');
  });

  test('unknown brands get a steady colour of their own', () {
    expect(brandAccent('Penrol'), brandAccent('penrol'));
    expect(brandAccent('Velox'), isNot(brandAccent('Penrol')));
    expect(brandAccent(''), const Color(0xFF111827));
  });

  testWidgets('a brand without a logo shows its initials on a disc', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [brandLogoWidget('Three L', 32), brandLogoWidget('', 32)],
          ),
        ),
      ),
    );
    expect(find.text('TL'), findsOneWidget);
    expect(find.byIcon(Icons.local_gas_station_rounded), findsOneWidget);
  });
}
