import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/app_circle_button.dart';
import 'package:gasolinahan/components/app_text_field.dart';

Widget _app(TargetPlatform platform, Widget child) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppCircleButton', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('exposes its tooltip as the accessible name on $platform', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            platform,
            AppCircleButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () {},
            ),
          ),
        );
        // Android announces the Tooltip message; iOS gets a Semantics label.
        final named = platform == TargetPlatform.android
            ? find.byTooltip('Back')
            : find.bySemanticsLabel('Back');
        expect(named, findsOneWidget);
        handle.dispose();
      });
    }

    testWidgets('keeps a 48dp tap target', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          AppCircleButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppCircleButton)), const Size(48, 48));
    });
  });

  group('AppTextField', () {
    testWidgets('shows a persistent label and the error below the field', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          AppTextField(
            controller: controller,
            label: 'Email',
            hint: 'you@mail.com',
            icon: Icons.mail_outline,
            errorText: 'Enter a valid email',
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a@b.c');
      await tester.pump();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('passes keyboard, action and autofill settings through', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          AppTextField(
            controller: controller,
            label: 'Email',
            hint: 'you@mail.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.emailAddress);
      expect(field.textInputAction, TextInputAction.next);
      expect(field.autofillHints, [AutofillHints.email]);
    });

    testWidgets('password toggle is labelled and flips its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var obscure = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _app(
            TargetPlatform.android,
            AppTextField(
              controller: controller,
              label: 'Password',
              hint: 'Your password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: obscure,
              onToggleObscure: () => setState(() => obscure = !obscure),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders a CupertinoTextField with its error on iOS', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          AppTextField(
            controller: controller,
            label: 'Name',
            hint: 'Juan Dela Cruz',
            icon: Icons.person_outline,
            errorText: 'Enter your name',
          ),
        ),
      );
      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(find.text('Enter your name'), findsOneWidget);
    });
  });
}
