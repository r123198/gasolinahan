import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/detour_advisor.dart';
import 'package:gasolinahan/models/station_model.dart';

const _metersPerDegreeLat = 111195.0;

StationModel station(String id, double metersNorth, double price) {
  return StationModel(
    id: id,
    name: id,
    brand: 'Shell',
    address: '',
    latitude: 14.5 + metersNorth / _metersPerDegreeLat,
    longitude: 121.0,
    regularPrice: price,
    premiumPrice: 0,
    dieselPrice: 0,
    lastUpdated: DateTime(2026),
  );
}

double regular(StationModel s) => s.regularPrice;

void main() {
  const userLat = 14.5;
  const userLng = 121.0;

  test('compares against the nearest other priced station', () {
    final near = station('near', 200, 60);
    final far = station('far', 3000, 57);
    final advice = adviseDetour(
      userLat: userLat,
      userLng: userLng,
      target: far,
      stations: [near, far],
      priceOf: regular,
      costPerKm: 2.5,
      liters: 20,
    );
    expect(advice, isNotNull);
    expect(advice!.nearest.id, 'near');
    expect(advice.verdict.savings, closeTo(60, 0.001)); // 3 pesos x 20 L
    // (3000 - 200) m x 1.3 road factor x 2 (there and back) = 7.28 km
    expect(advice.extraKm, closeTo(7.28, 0.01));
    expect(advice.verdict.detourCost, closeTo(18.2, 0.1));
    expect(advice.verdict.worthIt, isTrue);
  });

  test('has no advice when the target has no price', () {
    final near = station('near', 200, 60);
    final far = station('far', 3000, 0);
    expect(
      adviseDetour(
        userLat: userLat,
        userLng: userLng,
        target: far,
        stations: [near, far],
        priceOf: regular,
        costPerKm: 2.5,
        liters: 20,
      ),
      isNull,
    );
  });

  test('has no advice when there is nothing to compare against', () {
    final only = station('only', 500, 58);
    expect(
      adviseDetour(
        userLat: userLat,
        userLng: userLng,
        target: only,
        stations: [only],
        priceOf: regular,
        costPerKm: 2.5,
        liters: 20,
      ),
      isNull,
    );
  });

  test('the nearest station itself needs no detour', () {
    final near = station('near', 200, 60);
    final far = station('far', 3000, 57);
    final advice = adviseDetour(
      userLat: userLat,
      userLng: userLng,
      target: near,
      stations: [near, far],
      priceOf: regular,
      costPerKm: 2.5,
      liters: 20,
    );
    expect(advice!.extraKm, 0);
  });
}
