import 'package:cloud_firestore/cloud_firestore.dart';

class StationModel {
  final String id;
  final String name;
  final String brand;
  final String address;
  final double latitude;
  final double longitude;
  final double regularPrice;
  final double premiumPrice;
  final double dieselPrice;
  final DateTime lastUpdated;

  /// Latest reported price per product, e.g. {"XCS": 61.2}; grades only
  /// (the three fields above) for stations reported before products.
  final Map<String, double> productPrices;

  StationModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.regularPrice,
    required this.premiumPrice,
    required this.dieselPrice,
    required this.lastUpdated,
    this.productPrices = const {},
  });

  /// Name to show: the saved name, else "Shell station" (brand + station),
  /// else the address.
  /// Stations reported without a name come back as "Unknown Station".
  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty && n != unknownName) return n;
    if (brand.trim().isNotEmpty) return '${brand.trim()} station';
    if (address.trim().isNotEmpty) return address.trim();
    return 'Gas station';
  }

  static const unknownName = 'Unknown Station';

  factory StationModel.fromMap(Map<String, dynamic> data, String id) {
    return StationModel(
      id: id,
      name: data['name'] ?? 'Unknown Station',
      brand: data['brand'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      regularPrice: (data['regularPrice'] ?? 0.0).toDouble(),
      premiumPrice: (data['premiumPrice'] ?? 0.0).toDouble(),
      dieselPrice: (data['dieselPrice'] ?? 0.0).toDouble(),
      lastUpdated: _parseDateTime(data['lastUpdated']),
      productPrices: _parseProductPrices(data['productPrices']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'regularPrice': regularPrice,
      'premiumPrice': premiumPrice,
      'dieselPrice': dieselPrice,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'productPrices': productPrices,
    };
  }

  static Map<String, double> _parseProductPrices(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is num && value > 0) key: value.toDouble(),
    });
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
