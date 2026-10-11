import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/map_bottom_controls.dart';
import 'package:gasolinahan/viewmodels/trip_viewmodel.dart';
import 'package:provider/provider.dart';

import '../services/trip_viewmodel_test.dart'
    show FakeActivity, FakeConsent, FakeService, FakeSource;

void main() {
  testWidgets('tracking label fits beside the buttons on a 320px phone', (
    tester,
  ) async {
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
                onMyLocation: () {},
                onTrackingStarted: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Trip history'), findsOneWidget);
    expect(find.byTooltip('Go to my location'), findsOneWidget);
  });
}
