import 'fill_up_validator.dart' show parseNumber;

const minReportPrice = 30.0;
const maxReportPrice = 150.0;

/// Per-fuel errors for the price report form; [general] covers the form
/// as a whole (nothing entered).
class ReportPriceErrors {
  final String? regular;
  final String? premium;
  final String? diesel;
  final String? general;

  const ReportPriceErrors({
    this.regular,
    this.premium,
    this.diesel,
    this.general,
  });

  bool get isEmpty =>
      regular == null && premium == null && diesel == null && general == null;
}

/// Blank prices are allowed (that fuel wasn't on the board), but at least
/// one must be filled and every filled one must be believable.
ReportPriceErrors validateReportPrices({
  required String regular,
  required String premium,
  required String diesel,
}) {
  final texts = [regular, premium, diesel];
  if (texts.every((t) => t.trim().isEmpty)) {
    return const ReportPriceErrors(general: 'Enter at least one price');
  }
  return ReportPriceErrors(
    regular: _priceError(regular),
    premium: _priceError(premium),
    diesel: _priceError(diesel),
  );
}

String? _priceError(String text) {
  if (text.trim().isEmpty) return null;
  final price = parseNumber(text);
  if (price == null) return 'Enter a number, like 62.50';
  if (price < minReportPrice || price > maxReportPrice) {
    return 'Should be ₱30–₱150';
  }
  return null;
}

/// Errors for the per-product price rows (keyed by product name).
class ProductPriceErrors {
  final Map<String, String> byProduct;
  final String? general;

  const ProductPriceErrors({this.byProduct = const {}, this.general});

  bool get isEmpty => byProduct.isEmpty && general == null;
}

/// Like [validateReportPrices] for a brand's products: blanks are fine
/// (not on the board), but at least one price is needed.
ProductPriceErrors validateProductPrices(Map<String, String> texts) {
  if (texts.values.every((t) => t.trim().isEmpty)) {
    return const ProductPriceErrors(general: 'Enter at least one price');
  }
  return ProductPriceErrors(
    byProduct: {
      for (final MapEntry(:key, :value) in texts.entries)
        key: ?_priceError(value),
    },
  );
}
