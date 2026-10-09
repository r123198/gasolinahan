import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/views/auto_tracking_guide_view.dart';

void main() {
  testWidgets('shows setup steps for both iPhone and Android', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: AutoTrackingGuideView()),
    );
    expect(find.text('Track trips automatically'), findsOneWidget);
    expect(find.text('iPhone: CarPlay or car Bluetooth'), findsOneWidget);
    expect(find.text('Android: car Bluetooth'), findsOneWidget);
  });
}
