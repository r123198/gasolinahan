import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/brand_registry.dart';
import 'package:gasolinahan/models/station_naming.dart';

void main() {
  final petron = BrandRegistry.findByName('Petron')!;
  final seaoil = BrandRegistry.findByName('Seaoil')!;

  group('composeStationName', () {
    test('joins brand and branch', () {
      expect(composeStationName(petron, ' Mayapa '), 'Petron Mayapa');
    });

    test('is just the brand without a branch', () {
      expect(composeStationName(petron, '  '), 'Petron');
    });

    test('does not repeat a brand the user already typed', () {
      expect(composeStationName(petron, 'petron mayapa'), 'Petron mayapa');
    });
  });

  group('branchOf', () {
    test('strips the brand from the front of a saved name', () {
      expect(branchOf('Petron Mayapa', petron), 'Mayapa');
      expect(branchOf('SeaOil - Mayapa', seaoil), 'Mayapa');
      expect(branchOf('Sea Oil Real', seaoil), 'Real');
    });

    test('keeps names that do not start with the brand', () {
      expect(branchOf('Mayapa Petron', petron), 'Mayapa Petron');
    });

    test('is empty when the name is only the brand', () {
      expect(branchOf('Petron', petron), '');
    });
  });
}
