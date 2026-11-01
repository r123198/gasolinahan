import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A fuel product sold at a station (e.g. "Shell V-Power Racing")
class FuelProduct {
  final String name;
  final FuelCategory category; // maps to regular/premium/diesel for storage
  final Color color;

  const FuelProduct({
    required this.name,
    required this.category,
    required this.color,
  });
}

enum FuelCategory { regular, premium, diesel }

/// A gas station brand with its products and visual identity
class BrandInfo {
  final String name;
  final Color color;
  final String logoPath; // asset path (png or svg)
  final List<FuelProduct> products;

  /// Keywords that appear on price boards for this brand
  final List<String> ocrKeywords;

  const BrandInfo({
    required this.name,
    required this.color,
    required this.logoPath,
    required this.products,
    required this.ocrKeywords,
  });

  bool get isSvg => logoPath.endsWith('.svg');

  /// Emblem-only version of the logo (no wordmark), for round badges.
  String get markPath => logoPath.replaceFirst('/logos/', '/brand_marks/');

  /// The emblem at [size], fitted inside a square.
  Widget mark({double size = 24}) {
    final path = markPath;
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(path, width: size, height: size);
    }
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain);
  }

  /// Build the logo widget at a given size
  Widget logo({double size = 24}) {
    if (isSvg) {
      return SvgPicture.asset(logoPath, width: size, height: size);
    }
    return Image.asset(
      logoPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// The product called [name] (case-insensitive), if this brand sells it.
  FuelProduct? productNamed(String name) {
    final lower = name.trim().toLowerCase();
    return products.where((p) => p.name.toLowerCase() == lower).firstOrNull;
  }

  /// Get fuel products by category
  List<FuelProduct> byCategory(FuelCategory cat) =>
      products.where((p) => p.category == cat).toList();

  FuelProduct? get regularProduct =>
      products.where((p) => p.category == FuelCategory.regular).firstOrNull;
  FuelProduct? get premiumProduct =>
      products.where((p) => p.category == FuelCategory.premium).firstOrNull;
  FuelProduct? get dieselProduct =>
      products.where((p) => p.category == FuelCategory.diesel).firstOrNull;
}

class BrandRegistry {
  BrandRegistry._();

  static const _blue = Color(0xFF2563EB);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);

  static const _logoDir = 'assets/images/logos';
  static const _markDir = 'assets/images/brand_marks';

  static final List<BrandInfo> brands = [
    BrandInfo(
      name: 'Shell',
      color: const Color(0xFFFFC107),
      logoPath: '$_logoDir/shell.png',
      ocrKeywords: [
        'shell',
        'fuelsave',
        'fuel save',
        'v-power',
        'vpower',
        'v power',
        'shellsave',
      ],
      products: [
        FuelProduct(
          name: 'FuelSave Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'V-Power Gasoline',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'FuelSave Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
        FuelProduct(
          name: 'V-Power Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Petron',
      color: const Color(0xFFDC2626),
      logoPath: '$_logoDir/petron.svg',
      ocrKeywords: ['petron', 'xcs', 'blaze', 'turbo diesel', 'xtra advance'],
      products: [
        FuelProduct(
          name: 'Xtra Advance',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(name: 'XCS', category: FuelCategory.regular, color: _blue),
        FuelProduct(
          name: 'Blaze 100',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Turbo Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
        FuelProduct(
          name: 'Diesel Max',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Caltex',
      color: const Color(0xFF2563EB),
      logoPath: '$_logoDir/caltex.svg',
      ocrKeywords: [
        'caltex',
        'chevron',
        'silver',
        'gold',
        'techron',
        'havoline',
      ],
      products: [
        FuelProduct(
          name: 'Silver',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(name: 'Gold', category: FuelCategory.premium, color: _red),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Seaoil',
      color: const Color(0xFF7C3AED),
      logoPath: '$_logoDir/seaoil.png',
      ocrKeywords: ['seaoil', 'sea oil', 'extreme'],
      products: [
        FuelProduct(
          name: 'Extreme 95',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Extreme 97',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Extreme U',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Extreme Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Phoenix',
      color: const Color(0xFFEA580C),
      logoPath: '$_logoDir/phoenix.png',
      ocrKeywords: ['phoenix', 'pulse'],
      products: [
        FuelProduct(
          name: 'Premium 95',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Super 98',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Pulse Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Unioil',
      color: const Color(0xFF16A34A),
      logoPath: '$_logoDir/unioil.png',
      ocrKeywords: ['unioil', 'uni oil', 'unioplus'],
      products: [
        FuelProduct(
          name: 'Euro 4 Gasoline',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'UnioPlus',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Euro 5 Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Total',
      color: const Color(0xFFDC2626),
      logoPath: '$_logoDir/total.png',
      ocrKeywords: ['total', 'excellium'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Excellium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Jetti',
      color: const Color(0xFF0EA5E9),
      logoPath: '$_logoDir/jetti.png',
      ocrKeywords: ['jetti', 'jx'],
      products: [
        FuelProduct(
          name: 'JX Premium',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'JX Super',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'JX Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'PTT',
      color: const Color(0xFF0284C7),
      logoPath: '$_logoDir/ptt.svg',
      ocrKeywords: ['ptt', 'performa'],
      products: [
        FuelProduct(
          name: 'Performa Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Performa Super',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Hi-Cetane Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Cleanfuel',
      color: const Color(0xFF059669),
      logoPath: '$_logoDir/cleanfuel.png',
      ocrKeywords: ['cleanfuel', 'clean fuel'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Flying V',
      color: const Color(0xFF7C3AED),
      logoPath: '$_logoDir/flyingv.png',
      ocrKeywords: ['flying v', 'flyingv', 'flying-v'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium Plus',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel Plus',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    // Brands from the Northern Mindanao import. Emblem only so far (no
    // full logo): logoPath points straight at the mark.
    BrandInfo(
      name: 'Blu Energy',
      color: const Color(0xFF1D4ED8),
      logoPath: '$_markDir/blu-energy.jpeg',
      ocrKeywords: ['blu energy', 'bluenergy'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Velox',
      color: const Color(0xFF0F766E),
      logoPath: '$_markDir/velox.jpeg',
      ocrKeywords: ['velox'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'RM C Petrol',
      color: const Color(0xFF9A3412),
      logoPath: '$_markDir/rmc-petrol.jpeg',
      ocrKeywords: ['rm c petrol', 'rmc petrol'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Mobil',
      color: const Color(0xFFB91C1C),
      logoPath: '$_markDir/mobil.jpeg',
      ocrKeywords: ['mobil'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Petronas',
      color: const Color(0xFF0D9488),
      logoPath: '$_markDir/petronas.jpeg',
      ocrKeywords: ['petronas', 'primax'],
      products: [
        FuelProduct(
          name: 'Primax 95',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Primax 97',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Dynamic Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Aiji',
      color: const Color(0xFF4D7C0F),
      logoPath: '$_markDir/aiji.jpeg',
      ocrKeywords: ['aiji'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Apex',
      color: const Color(0xFF1E3A8A),
      logoPath: '$_markDir/apex.png',
      ocrKeywords: ['apex'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Eco Oil',
      color: const Color(0xFF15803D),
      logoPath: '$_markDir/eco_oil.jpeg',
      ocrKeywords: ['eco oil', 'ecooil'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Insular Oil',
      color: const Color(0xFF6D28D9),
      logoPath: '$_markDir/insular_oil.jpeg',
      ocrKeywords: ['insular oil', 'petro de oro'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Fuel Master',
      color: const Color(0xFFB45309),
      logoPath: '$_markDir/fuel_master.png',
      ocrKeywords: ['fuel master', 'fuelmaster'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'TecFuel',
      color: const Color(0xFF0369A1),
      logoPath: '$_markDir/tecfuel.jpeg',
      ocrKeywords: ['tecfuel', 'tec fuel'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
    BrandInfo(
      name: 'Quantum',
      color: const Color(0xFF7E22CE),
      logoPath: '$_markDir/quantum.webp',
      ocrKeywords: ['quantum'],
      products: [
        FuelProduct(
          name: 'Unleaded',
          category: FuelCategory.regular,
          color: _blue,
        ),
        FuelProduct(
          name: 'Premium',
          category: FuelCategory.premium,
          color: _red,
        ),
        FuelProduct(
          name: 'Diesel',
          category: FuelCategory.diesel,
          color: _green,
        ),
      ],
    ),
  ];

  /// Find a brand by name (case-insensitive)
  static BrandInfo? findByName(String name) {
    final lower = name.toLowerCase().trim();
    for (final b in brands) {
      if (b.name.toLowerCase() == lower) return b;
    }
    return null;
  }

  /// Other ways people type a brand in a station name.
  static const _nameAliases = {
    'Seaoil': ['sea oil'],
    'Unioil': ['uni oil'],
    'Flying V': ['flyingv', 'flying-v'],
    'Cleanfuel': ['clean fuel'],
    'Blu Energy': ['blu', 'bluenergy'],
    'RM C Petrol': ['rmc', 'rm-c', 'rmc petrol'],
    'Eco Oil': ['ecooil'],
    'Insular Oil': ['insular', 'petro de oro'],
    'Fuel Master': ['fuelmaster'],
    'TecFuel': ['tec fuel'],
  };

  /// Other spellings of [brand] people type, lower-case.
  static List<String> aliasesOf(BrandInfo brand) =>
      _nameAliases[brand.name] ?? const [];

  /// The brand named in free text such as "Petron Mayapa", matched on whole
  /// words so "Totalis" isn't read as Total.
  static BrandInfo? inferFromName(String text) {
    final lower =
        ' ${text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), ' ')} ';
    for (final b in brands) {
      final names = [b.name.toLowerCase(), ...?_nameAliases[b.name]];
      if (names.any((n) => lower.contains(' $n '))) return b;
    }
    return null;
  }

  /// The stored brand if it's known, otherwise one read from [stationName].
  static BrandInfo? match(String brand, {String stationName = ''}) =>
      findByName(brand) ?? inferFromName(stationName);

  /// Detect brand from OCR text
  static BrandInfo? detectFromOcr(String ocrText) {
    final text = ocrText.toLowerCase();
    for (final b in brands) {
      for (final kw in b.ocrKeywords) {
        if (text.contains(kw)) return b;
      }
    }
    return null;
  }

  /// Map of all product name keywords to their fuel category (for OCR matching)
  static final Map<String, FuelCategory> productKeywords =
      _buildProductKeywords();

  static Map<String, FuelCategory> _buildProductKeywords() {
    final map = <String, FuelCategory>{};
    for (final b in brands) {
      for (final p in b.products) {
        map[p.name.toLowerCase()] = p.category;
        for (final word in p.name.toLowerCase().split(' ')) {
          if (word.length > 2 && !_genericWords.contains(word)) {
            map[word] = p.category;
          }
        }
      }
    }
    return map;
  }

  static const _genericWords = {'euro', 'per', 'plus', 'max', 'super', 'new'};
}
