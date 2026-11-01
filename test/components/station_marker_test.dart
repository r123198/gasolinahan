import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/station_marker.dart';
import 'package:gasolinahan/models/station_model.dart';

StationModel station({
  String brand = 'Penrol',
  double regular = 0,
  String status = StationModel.operational,
}) => StationModel(
  id: 's1',
  name: 'Penrol Carmen',
  brand: brand,
  address: 'Carmen, CDO',
  latitude: 8.48,
  longitude: 124.64,
  regularPrice: regular,
  premiumPrice: 0,
  dieselPrice: 0,
  lastUpdated: StationModel.epoch,
  status: status,
);

Future<void> pump(WidgetTester tester, StationMarker marker) async {
  final size = stationMarkerSize(
    hasPrice: marker.tier != null,
    isCheapest: marker.tier == PriceTier.cheapest,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: marker,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('price tiers step up from the cheapest price', () {
    expect(priceTierOf(60, 60), PriceTier.cheapest);
    expect(priceTierOf(59.5, 60), PriceTier.cheapest);
    expect(priceTierOf(60.5, 60), PriceTier.low);
    expect(priceTierOf(61.5, 60), PriceTier.mid);
    expect(priceTierOf(61.51, 60), PriceTier.high);
  });

  test('marker boxes fit their content', () {
    final disc = stationMarkerSize(hasPrice: false, isCheapest: false);
    final pill = stationMarkerSize(hasPrice: true, isCheapest: false);
    final cheapest = stationMarkerSize(hasPrice: true, isCheapest: true);
    expect(disc.width < pill.width, isTrue);
    expect(cheapest.height > pill.height, isTrue);
  });

  testWidgets('a priced station shows its price; the cheapest says so', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      StationMarker(
        station: station(regular: 60.1),
        price: 60.1,
        tier: PriceTier.cheapest,
        onTap: () => taps++,
      ),
    );
    expect(find.text('₱60.10/L'), findsOneWidget);
    expect(find.text('Cheapest'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('cheapest nearby')), findsOneWidget);
    await tester.tap(find.text('₱60.10/L'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unpriced station is a brand disc with its initial', (
    tester,
  ) async {
    await pump(
      tester,
      StationMarker(station: station(), price: 0, tier: null, onTap: () {}),
    );
    expect(find.textContaining('₱'), findsNothing);
    expect(find.text('P'), findsOneWidget); // no Penrol logo yet
    expect(tester.takeException(), isNull);
  });

  testWidgets('a closed station is faded and says so', (tester) async {
    await pump(
      tester,
      StationMarker(
        station: station(status: 'temporarily_closed'),
        price: 0,
        tier: null,
        onTap: () {},
      ),
    );
    expect(find.bySemanticsLabel(RegExp('closed')), findsOneWidget);
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, lessThan(1));
  });
}
