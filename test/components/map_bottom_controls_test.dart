import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/map_bottom_controls.dart';
import 'package:gasolinahan/components/track_me_button.dart';
import 'package:gasolinahan/viewmodels/trip_viewmodel.dart';
import 'package:provider/provider.dart';

import '../services/trip_viewmodel_test.dart'
    show FakeActivity, FakeConsent, FakeService, FakeSource;

void main() {
  testWidgets('stacks search, report and my-location; hides Track me '
      'on a 320px phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final trips = TripViewModel(
      source: FakeSource(),
      service: FakeService(),
      activity: FakeActivity(),
      consent: FakeConsent(true),
    );
    addTearDown(trips.dispose);
    await tester.runAsync(() async {
      await trips.startMonitoring();
      await trips.trackNow();
    });
    expect(trips.isTracking, isTrue);
    var searches = 0;
    var reports = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: trips,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MapBottomControls(
                stationCount: 12,
                onShowStations: () {},
                onSearch: () => searches++,
                onReport: () => reports++,
                onMyLocation: () {},
                onTrackingStarted: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(showTrackMeControl, isFalse);
    expect(find.textContaining('Track'), findsNothing);
    expect(find.byTooltip('Trip history'), findsNothing);
    expect(find.byTooltip('Go to my location'), findsOneWidget);
    expect(find.text('Nearby stations'), findsOneWidget);

    // The three round buttons sit in one column on the right.
    final search = tester.getCenter(find.byTooltip('Search stations'));
    final report = tester.getCenter(find.byTooltip('Report a price'));
    final mine = tester.getCenter(find.byTooltip('Go to my location'));
    expect(search.dx, closeTo(report.dx, 1));
    expect(report.dx, closeTo(mine.dx, 1));
    expect(search.dy < report.dy && report.dy < mine.dy, isTrue);

    await tester.tap(find.byTooltip('Search stations'));
    await tester.tap(find.byTooltip('Report a price'));
    expect(searches, 1);
    expect(reports, 1);
  });

  testWidgets('stopping tracking tells the map to stop following', (
    tester,
  ) async {
    final trips = TripViewModel(
      source: FakeSource(),
      service: FakeService(),
      activity: FakeActivity(),
      consent: FakeConsent(true),
      currentUserId: () => null,
    );
    addTearDown(trips.dispose);
    await tester.runAsync(() async {
      await trips.startMonitoring();
      await trips.trackNow();
    });
    var stopped = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: trips,
        child: MaterialApp(
          home: Scaffold(body: TrackMeButton(onStopped: () => stopped++)),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.textContaining('Stop'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(trips.isTracking, isFalse);
    expect(stopped, 1);
  });

  testWidgets('without onReport (the web) there is no report button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MapBottomControls(
              stationCount: 12,
              onShowStations: () {},
              onSearch: () {},
              onMyLocation: () {},
              onTrackingStarted: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Report a price'), findsNothing);
    expect(find.byTooltip('Search stations'), findsOneWidget);
    expect(find.byTooltip('Go to my location'), findsOneWidget);
  });
}
