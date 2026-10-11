import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/services/sync_service.dart';

void main() {
  test('decodes stored product prices', () {
    expect(decodeProductPrices('{"XCS": 61.2, "Turbo Diesel": 55}'), {
      'XCS': 61.2,
      'Turbo Diesel': 55.0,
    });
  });

  test('bad or missing data decodes to nothing', () {
    expect(decodeProductPrices(null), isEmpty);
    expect(decodeProductPrices('not json'), isEmpty);
    expect(decodeProductPrices('{"XCS": "x", "Bad": -1}'), isEmpty);
  });

  test('pending rows carry their points; old rows earn none', () {
    expect(pointsOf({'pointsAwarded': 6}), 6);
    expect(pointsOf({}), 0);
    expect(pointsOf({'pointsAwarded': 'x'}), 0);
  });
}
