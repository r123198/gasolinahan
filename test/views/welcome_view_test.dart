import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/services/onboarding_prefs.dart';
import 'package:gasolinahan/views/welcome_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpWelcome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: const WelcomeView(nextRoute: '/login'),
      routes: {'/login': (_) => const Scaffold(body: Text('Sign in page'))},
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Next walks through the pages to Get started', (tester) async {
    await pumpWelcome(tester);
    expect(find.text('Find the cheapest gas near you'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Prices change every Tuesday'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in page'), findsOneWidget);
  });

  testWidgets('Skip with "Don\'t show this again" opts out', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(find.text("Don't show this again"));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in page'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_never_show'), isTrue);
    expect(
      await OnboardingPrefs().checkAndRecordLaunch(DateTime(2030)),
      isFalse,
    );
  });

  testWidgets('Skip without the checkbox does not opt out', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_never_show'), isNull);
  });
}
