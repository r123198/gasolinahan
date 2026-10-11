import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/components/detour_card.dart';
import 'package:gasolinahan/models/detour_advisor.dart';
import 'package:gasolinahan/models/fuel_insights.dart';
import 'package:gasolinahan/models/station_model.dart';

DetourAdvice advice({required String name, required double savings}) =>
    DetourAdvice(
      nearest: StationModel(
        id: 'near',
        name: name,
        brand: 'Shell',
        address: '',
        latitude: 14.5,
        longitude: 121.0,
        regularPrice: 60,
        premiumPrice: 0,
        dieselPrice: 0,
        lastUpdated: DateTime(2026),
      ),
      priceHere: 60,
      priceThere: 62,
      extraKm: 4,
      verdict: DetourVerdict(savings: savings, detourCost: 10),
      isClosest: false,
    );

void main() {
  test('says how much a cheaper station saves', () {
    final text = detourDetail(advice(name: 'Shell EDSA', savings: 45), 15);

    expect(text, contains('Here saves ~₱45 on 15 L'));
  });

  test('says a pricier station costs more instead of saving ₱0', () {
    final text = detourDetail(advice(name: 'Shell EDSA', savings: -30), 15);

    expect(text, contains('Here costs ~₱30 more on 15 L'));
    expect(text, isNot(contains('saves')));
  });

  test('names an unnamed nearest station by its brand', () {
    final text = detourDetail(
      advice(name: StationModel.unknownName, savings: 10),
      15,
    );

    expect(text, startsWith('Shell station is closer'));
  });
}
