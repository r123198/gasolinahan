import 'brand_registry.dart';

/// "Petron" + "Mayapa" → "Petron Mayapa". A branch that already starts with
/// the brand is kept as typed, so it isn't doubled.
String composeStationName(BrandInfo brand, String branch) {
  final b = branch.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (b.isEmpty) return brand.name;
  final typedBrand = _brandPrefixLength(b, brand);
  if (typedBrand > 0) return '${brand.name}${b.substring(typedBrand)}';
  return '${brand.name} $b';
}

/// The part of [stationName] after its brand: "SeaOil - Mayapa" → "Mayapa".
String branchOf(String stationName, BrandInfo brand) {
  final name = stationName.trim();
  final cut = _brandPrefixLength(name, brand);
  if (cut == 0) return name;
  return name.substring(cut).replaceFirst(RegExp(r'^[\s\-·:,]+'), '').trim();
}

/// Length of the brand (or a spelling of it) at the start of [text], or 0.
int _brandPrefixLength(String text, BrandInfo brand) {
  final lower = text.toLowerCase();
  final spellings = [
    brand.name.toLowerCase(),
    ...BrandRegistry.aliasesOf(brand),
  ]..sort((a, b) => b.length.compareTo(a.length));
  for (final s in spellings) {
    if (lower == s || lower.startsWith('$s ') || lower.startsWith('$s-')) {
      return s.length;
    }
  }
  return 0;
}
