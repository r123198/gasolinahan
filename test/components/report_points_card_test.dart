import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/report_points_card.dart';
import 'package:gasolinahan/models/points_rules.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('shows the total, the breakdown and tier progress', (
    tester,
  ) async {
    final award = pointsForReport(const ReportContext(productCount: 3));
    await pump(
      tester,
      ReportPointsCard(award: award, savedOffline: false, lifetimeBefore: 130),
    );
    expect(find.text('+6 points'), findsOneWidget);
    expect(find.text('Price report'), findsOneWidget);
    expect(find.text('3 prices'), findsOneWidget);
    // 136 lifetime → 14 to Silver (150).
    expect(find.bySemanticsLabel('14 points to Silver'), findsOneWidget);
  });

  testWidgets('pending reports say points come after review', (tester) async {
    final award = pointsForReport(
      const ReportContext(productCount: 3, isOutlier: true),
    );
    await pump(tester, ReportPointsCard(award: award, savedOffline: false));
    expect(find.text('Points after review'), findsOneWidget);
  });

  testWidgets('no points explains why', (tester) async {
    final award = pointsForReport(
      const ReportContext(productCount: 3, alreadyRewardedStationToday: true),
    );
    await pump(tester, ReportPointsCard(award: award, savedOffline: false));
    expect(find.text('No points this time'), findsOneWidget);
    expect(
      find.text('Already rewarded for this station today'),
      findsOneWidget,
    );
  });

  testWidgets('offline reports say points arrive on sync', (tester) async {
    final award = pointsForReport(const ReportContext(productCount: 2));
    await pump(tester, ReportPointsCard(award: award, savedOffline: true));
    expect(find.text('Added when your report syncs.'), findsOneWidget);
  });

  testWidgets('preview says "Earn at least" or the reason', (tester) async {
    await pump(
      tester,
      ReportPointsPreview(
        estimate: pointsForReport(const ReportContext(productCount: 3)),
      ),
    );
    expect(find.text('Earn at least 6 points'), findsOneWidget);

    await pump(
      tester,
      ReportPointsPreview(
        estimate: pointsForReport(
          const ReportContext(productCount: 3, isAtStation: false),
        ),
      ),
    );
    expect(find.text('Report from the station to earn points'), findsOneWidget);
  });
}
