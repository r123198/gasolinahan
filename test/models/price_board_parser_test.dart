import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/brand_registry.dart';
import 'package:gasolinahan/models/price_board_parser.dart';

BrandInfo brand(String name) => BrandRegistry.findByName(name)!;

void main() {
  group('Petron board', () {
    final petron = brand('Petron');

    test('reads every product with its own price', () {
      final r = parsePriceBoard([
        'PETRON\nXCS 61.20\nTURBO DIESEL 55.10\nDIESEL MAX 54.80\nBLAZE 100 68.90',
      ], brand: petron);
      expect(r.productPrices, {
        'XCS': 61.20,
        'Turbo Diesel': 55.10,
        'Diesel Max': 54.80,
        'Blaze 100': 68.90,
      });
    });

    test('grade price is the first product of that grade on the board', () {
      final r = parsePriceBoard([
        'XCS 61.20\nTURBO DIESEL 55.10\nDIESEL MAX 54.80\nBLAZE 100 68.90',
      ], brand: petron);
      expect(r.regular, 61.20);
      expect(r.diesel, 55.10);
      expect(r.premium, 68.90);
    });

    test('tolerates OCR noise: XC5, extra spaces, comma decimals', () {
      final r = parsePriceBoard([
        'XC5    61,20\nDIESEL   MAX 54.80',
      ], brand: petron);
      expect(r.productPrices, {'XCS': 61.20, 'Diesel Max': 54.80});
    });

    test('pairs a name with the price on the next line', () {
      final r = parsePriceBoard(['Turbo Diesel\n55.10'], brand: petron);
      expect(r.productPrices, {'Turbo Diesel': 55.10});
    });

    test('pairs a column of names with a column of prices', () {
      final r = parsePriceBoard([
        'XCS\nTurbo Diesel',
        '61.20\n55.10',
      ], brand: petron);
      expect(r.productPrices, {'XCS': 61.20, 'Turbo Diesel': 55.10});
    });

    test('ignores prices outside ₱30–₱150', () {
      final r = parsePriceBoard([
        'XCS 6.12\nTurbo Diesel 155.10',
      ], brand: petron);
      expect(r.productPrices, isEmpty);
      expect(r.isEmpty, isTrue);
    });
  });

  test('Shell keeps both diesels as separate products', () {
    final r = parsePriceBoard([
      'FuelSave Unleaded 63.45\nV-Power Gasoline 70.10\n'
          'FuelSave Diesel 58.20\nV-POWER DIESEL 64.90',
    ], brand: brand('Shell'));
    expect(r.productPrices, {
      'FuelSave Unleaded': 63.45,
      'V-Power Gasoline': 70.10,
      'FuelSave Diesel': 58.20,
      'V-Power Diesel': 64.90,
    });
    expect(r.diesel, 58.20);
    expect(r.premium, 70.10);
    expect(r.regular, 63.45);
  });

  test('Caltex Silver, Gold and Diesel', () {
    final r = parsePriceBoard([
      'CALTEX\nSilver 62.10\nGold 66.40\nDiesel 57.30',
    ], brand: brand('Caltex'));
    expect(r.productPrices, {'Silver': 62.10, 'Gold': 66.40, 'Diesel': 57.30});
    expect((r.regular, r.premium, r.diesel), (62.10, 66.40, 57.30));
  });

  test('board without a known brand fills grades only', () {
    final r = parsePriceBoard(['UNLEADED 60.00\nPREMIUM 65.50\nDIESEL 55.25']);
    expect(r.productPrices, isEmpty);
    expect((r.regular, r.premium, r.diesel), (60.00, 65.50, 55.25));
  });

  test('unknown brand still maps product names to their grade', () {
    final r = parsePriceBoard(['Turbo Diesel 55.10\nRON 95 64.00']);
    expect(r.productPrices, isEmpty);
    expect(r.diesel, 55.10);
    expect(r.premium, 64.00);
  });

  test('generic labels fill a grade the brand board did not name', () {
    final r = parsePriceBoard([
      'XCS 61.20\nDIESEL 55.10',
    ], brand: brand('Petron'));
    expect(r.productPrices, {'XCS': 61.20});
    expect(r.diesel, 55.10);
  });

  test('prices with no labels fall back to cheapest-is-diesel order', () {
    final r = parsePriceBoard(['61.20\n55.10\n68.90']);
    expect((r.regular, r.premium, r.diesel), (61.20, 68.90, 55.10));
  });

  test('gradeOf finds the grade of a known product', () {
    expect(gradeOfProduct(brand('Petron'), 'Diesel Max'), FuelCategory.diesel);
    expect(gradeOfProduct(brand('Petron'), 'Unknown'), isNull);
  });

  group('grades and products', () {
    final petron = brand('Petron');

    test("grade prices come from the brand's first priced product", () {
      final g = gradesFromProducts(petron, {
        'Diesel Max': 54.80,
        'Turbo Diesel': 55.10,
        'XCS': 61.20,
      });
      // Petron lists Turbo Diesel before Diesel Max.
      expect(g, {FuelCategory.diesel: 55.10, FuelCategory.regular: 61.20});
    });

    test('a grade-only reading fills that grade\'s first product', () {
      final r = parsePriceBoard(['XCS 61.20\nDIESEL 55.10'], brand: petron);
      expect(productPricesForForm(petron, r), {
        'XCS': 61.20,
        'Turbo Diesel': 55.10,
      });
    });

    test('products already read are kept as they are', () {
      final r = parsePriceBoard(['Diesel Max 54.80'], brand: petron);
      expect(productPricesForForm(petron, r), {'Diesel Max': 54.80});
    });
  });
}
