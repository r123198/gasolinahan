import 'brand_registry.dart';

const minBoardPrice = 30.0;
const maxBoardPrice = 150.0;

final _pricePattern = RegExp(r'(\d{2,3})[.,](\d{2})');

/// What a photo of a station's price board says.
class PriceBoardResult {
  /// Price per product of the detected brand, keyed by the registry's
  /// product name (e.g. "XCS", "Turbo Diesel"). Empty when the brand is
  /// unknown — then only the grades below are filled.
  final Map<String, double> productPrices;

  /// Grade prices; 0 when not found. Each grade takes the FIRST price of
  /// that grade on the board (boards list the everyday product first).
  final double regular;
  final double premium;
  final double diesel;

  const PriceBoardResult({
    this.productPrices = const {},
    this.regular = 0,
    this.premium = 0,
    this.diesel = 0,
  });

  bool get isEmpty =>
      productPrices.isEmpty && regular == 0 && premium == 0 && diesel == 0;
}

/// Grade prices implied by [prices] (product → ₱/L): for each grade, the
/// first of [brand]'s products, in the brand's own order, that has a price.
Map<FuelCategory, double> gradesFromProducts(
  BrandInfo brand,
  Map<String, double> prices,
) {
  final grades = <FuelCategory, double>{};
  for (final product in brand.products) {
    final price = prices[product.name];
    if (price != null && price > 0) {
      grades.putIfAbsent(product.category, () => price);
    }
  }
  return grades;
}

/// Product prices to prefill the report form with: what the board named,
/// plus — for a grade read only by a generic word ("DIESEL 55.10") — that
/// price on the brand's first product of the grade.
Map<String, double> productPricesForForm(
  BrandInfo brand,
  PriceBoardResult result,
) {
  final prices = {...result.productPrices};
  final read = {
    FuelCategory.regular: result.regular,
    FuelCategory.premium: result.premium,
    FuelCategory.diesel: result.diesel,
  };
  for (final MapEntry(key: grade, value: price) in read.entries) {
    if (price <= 0) continue;
    final ofGrade = brand.byCategory(grade);
    if (ofGrade.isEmpty || ofGrade.any((p) => prices.containsKey(p.name))) {
      continue;
    }
    prices[ofGrade.first.name] = price;
  }
  return prices;
}

/// The grade [productName] belongs to at [brand], if it's one of its products.
FuelCategory? gradeOfProduct(BrandInfo brand, String productName) =>
    brand.productNamed(productName)?.category;

/// Reads a price board from OCR [blocks] (one string per recognised text
/// block, lines kept). Labels are matched to [brand]'s products first
/// (longest name wins, so "Turbo Diesel" beats "Diesel"), then to generic
/// grade words (unleaded, premium, diesel, RON 91/95/97). A name and its
/// price may share a line, sit on adjacent lines, or stand in separate
/// columns. With no labels at all, prices fall back to their usual order:
/// cheapest diesel, then regular, then premium.
PriceBoardResult parsePriceBoard(List<String> blocks, {BrandInfo? brand}) {
  final products = <String, double>{};
  final grades = <FuelCategory, double>{};
  final unpairedLabels = <_Label>[];
  final unpairedPrices = <double>[];
  final allPrices = <double>[];

  void record(_Label label, double price) {
    final product = label.product;
    if (product != null && brand != null) {
      products.putIfAbsent(product.name, () => price);
    }
    grades.putIfAbsent(label.grade, () => price);
  }

  for (final block in blocks) {
    _Label? pending;
    for (final line in block.split('\n')) {
      final prices = _pricesIn(line);
      allPrices.addAll(prices);
      final label = _matchLabel(line.replaceAll(_pricePattern, ' '), brand);
      if (label != null && prices.isNotEmpty) {
        if (pending != null) unpairedLabels.add(pending);
        pending = null;
        record(label, prices.first);
      } else if (label != null) {
        if (pending != null) unpairedLabels.add(pending);
        pending = label;
      } else if (prices.isNotEmpty) {
        if (pending != null) {
          record(pending, prices.first);
          pending = null;
        } else {
          unpairedPrices.add(prices.first);
        }
      }
    }
    if (pending != null) unpairedLabels.add(pending);
  }

  // A column of names beside a column of prices.
  if (unpairedLabels.isNotEmpty &&
      unpairedLabels.length == unpairedPrices.length) {
    for (var i = 0; i < unpairedLabels.length; i++) {
      record(unpairedLabels[i], unpairedPrices[i]);
    }
  }

  if (products.isEmpty && grades.isEmpty) {
    return _positionalFallback(allPrices);
  }
  return PriceBoardResult(
    productPrices: Map.unmodifiable(products),
    regular: grades[FuelCategory.regular] ?? 0,
    premium: grades[FuelCategory.premium] ?? 0,
    diesel: grades[FuelCategory.diesel] ?? 0,
  );
}

PriceBoardResult _positionalFallback(List<double> prices) {
  final sorted = [...prices]..sort();
  if (sorted.length < 2) return const PriceBoardResult();
  if (sorted.length == 2) {
    return PriceBoardResult(regular: sorted[0], premium: sorted[1]);
  }
  return PriceBoardResult(
    diesel: sorted[0],
    regular: sorted[1],
    premium: sorted[2],
  );
}

List<double> _pricesIn(String line) => [
  for (final m in _pricePattern.allMatches(line))
    if (_toPrice(m) case final p when p >= minBoardPrice && p <= maxBoardPrice)
      p,
];

double _toPrice(RegExpMatch m) =>
    int.parse(m.group(1)!) + int.parse(m.group(2)!) / 100;

class _Label {
  final FuelProduct? product;
  final FuelCategory grade;

  const _Label(this.grade, [this.product]);
}

/// Folds OCR look-alikes (5→s, 0→o, 1/|→l) and drops spaces/punctuation,
/// so "XC5", "V-POWER  DIESEL" and "Blaze 100" compare reliably.
String _fold(String text) => text
    .toLowerCase()
    .replaceAll('5', 's')
    .replaceAll('0', 'o')
    .replaceAll(RegExp(r'[1|]'), 'l')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Grade words, most specific first (a "premium diesel" is diesel).
final _genericGrades = <(String, FuelCategory)>[
  for (final w in ['diesel', 'dsl']) (_fold(w), FuelCategory.diesel),
  for (final w in ['premium', 'super', 'ron 95', 'ron 97'])
    (_fold(w), FuelCategory.premium),
  for (final w in ['unleaded', 'regular', 'gasoline', 'ron 91'])
    (_fold(w), FuelCategory.regular),
];

/// Products to try, longest folded name first.
List<(String, FuelProduct)> _productsByLength(Iterable<FuelProduct> products) =>
    [for (final p in products) (_fold(p.name), p)]
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));

final _allProducts = _productsByLength(
  BrandRegistry.brands.expand((b) => b.products),
);

_Label? _matchLabel(String text, BrandInfo? brand) {
  final folded = _fold(text);
  if (folded.isEmpty) return null;
  final candidates = brand == null
      ? _allProducts
      : _productsByLength(brand.products);
  for (final (name, product) in candidates) {
    if (folded.contains(name)) {
      return _Label(product.category, brand == null ? null : product);
    }
  }
  for (final (word, grade) in _genericGrades) {
    if (folded.contains(word)) return _Label(grade);
  }
  return null;
}

/// Keywords that indicate a fuel price board
const _fuelKeywords = [
  // Fuel types
  'regular', 'unleaded', 'premium', 'super', 'diesel', 'dsl',
  'gasoline', 'gasolin', 'gasolina', 'kerosene',
  // Octane ratings
  'ron', '87', '91', '93', '95', '97',
  'octane',
  // Brands & product names
  'v-power', 'vpower', 'xcs', 'blaze', 'turbo', 'xtreme',
  'fuel', 'petrol',
  // Board context
  'price', 'prices', 'presyo', 'per liter', 'per litre', '/l',
  'pump', 'station',
  // Philippine brands
  'shell', 'petron', 'caltex', 'seaoil', 'unioil', 'phoenix',
  'total', 'ptt', 'jetti', 'cleanfuel', 'flying v',
];

/// Minimum number of fuel keywords that must appear to consider it a price board
const _minKeywordMatches = 2;

/// Check if the OCR text contains enough fuel-related keywords to be a price board
bool looksLikePriceBoard(String rawText) {
  final text = rawText.toLowerCase();

  // Count how many fuel keywords appear
  int keywordHits = 0;
  final matched = <String>{};
  for (final kw in _fuelKeywords) {
    if (text.contains(kw) && !matched.contains(kw)) {
      matched.add(kw);
      keywordHits++;
    }
  }

  // Also check for price-like patterns (XX.XX or XX,XX in the 30-150 range)
  final pricePattern = RegExp(r'(\d{2,3})[.,](\d{2})');
  final priceMatches = pricePattern.allMatches(text);
  int validPriceCount = 0;
  for (final match in priceMatches) {
    final whole = int.tryParse(match.group(1)!) ?? 0;
    final decimal = int.tryParse(match.group(2)!) ?? 0;
    final price = whole + decimal / 100.0;
    if (price >= 30 && price <= 150) {
      validPriceCount++;
    }
  }

  // Must have at least 2 fuel keywords AND at least 1 valid price
  // OR at least 1 fuel keyword AND at least 2 valid prices
  return (keywordHits >= _minKeywordMatches && validPriceCount >= 1) ||
      (keywordHits >= 1 && validPriceCount >= 2);
}
