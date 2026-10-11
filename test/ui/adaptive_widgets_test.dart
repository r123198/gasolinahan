import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/app_primary_button.dart';
import 'package:gasolinahan/components/app_text_field.dart';
import 'package:gasolinahan/ui/adaptive/app_icon_button.dart';
import 'package:gasolinahan/ui/adaptive/app_nav_bar.dart';
import 'package:gasolinahan/ui/adaptive/app_page_route.dart';
import 'package:gasolinahan/ui/adaptive/app_sheet.dart';
import 'package:gasolinahan/ui/adaptive/app_spinner.dart';
import 'package:gasolinahan/ui/adaptive/app_tappable.dart';
import 'package:gasolinahan/ui/adaptive/app_toast.dart';

Widget _app(TargetPlatform platform, Widget home) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: home,
);

void main() {
  group('AppSpinner', () {
    testWidgets('renders CupertinoActivityIndicator on iOS', (tester) async {
      await tester.pumpWidget(
        _app(TargetPlatform.iOS, const Scaffold(body: AppSpinner(size: 20))),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders CircularProgressIndicator on Android', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          const Scaffold(body: AppSpinner(size: 20)),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  });

  group('AppPrimaryButton', () {
    testWidgets('uses CupertinoButton on iOS and fires onPressed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Scaffold(
            body: AppPrimaryButton(label: 'Go', onPressed: () => taps++),
          ),
        ),
      );
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('uses ElevatedButton on Android', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          Scaffold(
            body: AppPrimaryButton(label: 'Go', onPressed: () {}),
          ),
        ),
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(CupertinoButton), findsNothing);
    });

    testWidgets('ignores taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Scaffold(
            body: AppPrimaryButton(
              label: 'Go',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CupertinoButton));
      expect(taps, 0);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('uses CupertinoTextField on iOS', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Scaffold(
            body: AppTextField(
              controller: controller,
              label: 'EMAIL',
              hint: 'you@mail.com',
              icon: Icons.mail,
            ),
          ),
        ),
      );
      expect(find.byType(CupertinoTextField), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), 'a@b.c');
      expect(controller.text, 'a@b.c');
    });

    testWidgets('uses TextField on Android', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          Scaffold(
            body: AppTextField(
              controller: controller,
              hint: 'Search',
              icon: Icons.search,
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CupertinoTextField), findsNothing);
    });
  });

  group('AppIconButton / AppTappable', () {
    testWidgets('iOS icon button taps without a ripple widget', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Scaffold(
            body: AppIconButton(
              icon: const Icon(Icons.close),
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byType(IconButton), findsNothing);
      await tester.tap(find.byIcon(Icons.close));
      expect(taps, 1);
    });

    testWidgets('AppTappable uses InkWell on Android, fade on iOS', (
      tester,
    ) async {
      Widget build(TargetPlatform p) => _app(
        p,
        Scaffold(
          body: AppTappable(onTap: () {}, child: const Text('row')),
        ),
      );

      await tester.pumpWidget(build(TargetPlatform.android));
      expect(find.byType(InkWell), findsOneWidget);

      await tester.pumpWidget(build(TargetPlatform.iOS));
      await tester.pumpAndSettle(); // MaterialApp animates theme changes
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });
  });

  group('AppNavBar', () {
    testWidgets('iOS shows CupertinoNavigationBar with title', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          const Scaffold(appBar: AppNavBar(title: 'Privacy')),
        ),
      );
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('Android shows AppBar with title', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          const Scaffold(appBar: AppNavBar(title: 'Privacy')),
        ),
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
    });
  });

  group('appRoute', () {
    testWidgets('returns CupertinoPageRoute on iOS', (tester) async {
      late Route<void> route;
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Builder(
            builder: (context) {
              route = appRoute<void>(context, (_) => const SizedBox());
              return const SizedBox();
            },
          ),
        ),
      );
      expect(route, isA<CupertinoPageRoute<void>>());
    });

    testWidgets('returns MaterialPageRoute on Android', (tester) async {
      late Route<void> route;
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          Builder(
            builder: (context) {
              route = appRoute<void>(context, (_) => const SizedBox());
              return const SizedBox();
            },
          ),
        ),
      );
      expect(route, isA<MaterialPageRoute<void>>());
    });
  });

  group('showAppToast', () {
    testWidgets('iOS shows an overlay banner, not a SnackBar', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppToast(context, 'Saved'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('Android shows a SnackBar', (tester) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppToast(context, 'Saved'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('showAppActionSheet', () {
    testWidgets('iOS shows CupertinoActionSheet and returns the value', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppActionSheet<String>(
                    context: context,
                    actions: const [
                      AppSheetAction(label: 'Camera', value: 'camera'),
                      AppSheetAction(label: 'Gallery', value: 'gallery'),
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(result, 'gallery');
    });
  });

  group('showAppSheet', () {
    testWidgets('iOS hosts a DraggableScrollableSheet without layout errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TargetPlatform.iOS,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.5,
                    maxChildSize: 0.8,
                    minChildSize: 0.3,
                    expand: false,
                    builder: (_, controller) => ListView(
                      controller: controller,
                      children: const [ListTile(title: Text('row 1'))],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('row 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final sheetHeight = tester
          .getSize(find.byType(DraggableScrollableSheet))
          .height;
      expect(sheetHeight, greaterThan(100));
    });
  });

  testWidgets('iOS sheet content gets no status-bar inset at the top', (
    tester,
  ) async {
    double? topInset;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: (sheetContext) {
                  topInset = MediaQuery.paddingOf(sheetContext).top;
                  return const SafeArea(child: Text('sheet'));
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(topInset, 0);
  });
}
