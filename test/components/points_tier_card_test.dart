import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/points_tier_card.dart';

Future<void> pump(WidgetTester tester, int lifetime) async {
  tester.view.physicalSize = const Size(320 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PointsTierCard(points: lifetime, lifetimePoints: lifetime),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the tier and how far the next one is', (tester) async {
    await pump(tester, 136);
    expect(find.text('Bronze member'), findsOneWidget);
    expect(find.text('14 points to Silver'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top tier says so', (tester) async {
    await pump(tester, 3000);
    expect(find.text('Platinum member'), findsOneWidget);
    expect(find.text('Top tier reached. Thank you!'), findsOneWidget);
  });
}
