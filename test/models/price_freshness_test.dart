import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/price_freshness.dart';

void main() {
  group('latestPriceChange', () {
    test('is this Tuesday 6 AM once it has passed', () {
      // Sun Oct 11 2026 → last change Tue Oct 6, 6:00.
      expect(
        latestPriceChange(DateTime(2026, 10, 11, 9)),
        DateTime(2026, 10, 6, 6),
      );
    });

    test('before 6 AM on a Tuesday it is the previous week', () {
      expect(
        latestPriceChange(DateTime(2026, 10, 13, 5, 59)),
        DateTime(2026, 10, 6, 6),
      );
    });

    test('from 6 AM on a Tuesday it is that morning', () {
      expect(
        latestPriceChange(DateTime(2026, 10, 13, 6)),
        DateTime(2026, 10, 13, 6),
      );
    });
  });

  group('pricesMayHaveChanged', () {
    final now = DateTime(2026, 10, 11, 9); // Sunday

    test('a report from before Tuesday is out of date', () {
      expect(pricesMayHaveChanged(DateTime(2026, 10, 5, 20), now), isTrue);
    });

    test('a report since Tuesday 6 AM is current', () {
      expect(pricesMayHaveChanged(DateTime(2026, 10, 6, 7), now), isFalse);
    });
  });
}
