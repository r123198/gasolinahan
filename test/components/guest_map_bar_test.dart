import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/guest_map_bar.dart';

void main() {
  Future<({List<String> tapped})> pumpBar(WidgetTester tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuestMapBar(
            onAbout: () => tapped.add('about'),
            onSignIn: () => tapped.add('sign in'),
          ),
        ),
      ),
    );
    return (tapped: tapped);
  }

  testWidgets('sign in button asks the guest to sign in', (tester) async {
    final bar = await pumpBar(tester);

    await tester.tap(find.text('Sign in'));

    expect(bar.tapped, ['sign in']);
  });

  testWidgets('the name opens the about page', (tester) async {
    final bar = await pumpBar(tester);

    await tester.tap(find.text('Gasolinahan'));

    expect(bar.tapped, ['about']);
  });
}
