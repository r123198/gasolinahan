import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/views/tracking_disclosure_sheet.dart';

Future<bool?> _openAndTap(WidgetTester tester, String button) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showTrackingDisclosure(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('states background location use before asking', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TrackingDisclosure())),
    );

    expect(
      find.textContaining('even when the app is closed or not in use'),
      findsOneWidget,
    );
    expect(find.textContaining('physical activity'), findsWidgets);
  });

  testWidgets('resolves true when the user turns it on', (tester) async {
    expect(await _openAndTap(tester, 'Turn on'), isTrue);
  });

  testWidgets('resolves false when the user says not now', (tester) async {
    expect(await _openAndTap(tester, 'Not now'), isFalse);
  });

  testWidgets('resolves null when dismissed without an answer', (tester) async {
    bool? result = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showTrackingDisclosure(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // outside the sheet
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
