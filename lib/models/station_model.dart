import 'package:cloud_firestore/cloud_firestore.dart';

/// What a station offers besides fuel. Each value is true or false when
/// the source (Google's listing or a user) says so, and null when nothing
/// is listed, so "unknown" never reads as "no".
class StationAmenities {
  final bool? restroom;
  final bool? accessibleRestroom;
  final bool? convenienceStore;
  final bool? airPump;
  final bool? atm;
  final bool? carWash;
  final bool? oilChange;
  final bool? cardsAccepted;
  final bool? open24Hours;

  const StationAmenities({
    this.restroom,
    this.accessibleRestroom,
    this.convenienceStore,
    this.airPump,
    this.atm,
    this.carWash,
    this.oilChange,
    this.cardsAccepted,
    this.open24Hours,
  });

  static const none = StationAmenities();

  /// Firestore field names on a station document.
  static const keys = [
    'restroom',
    'accessibleRestroom',
    'convenienceStore',
    'airPump',
    'atm',
    'carWash',
    'oilChange',
    'cardsAccepted',
    'open24Hours',
  ];

  factory StationAmenities.fromMap(Object? value) {
    if (value is! Map) return none;
    bool? flag(String key) => value[key] is bool ? value[key] as bool : null;
    return StationAmenities(
      restroom: flag('restroom'),
      accessibleRestroom: flag('accessibleRestroom'),
      convenienceStore: flag('convenienceStore'),
      airPump: flag('airPump'),
      atm: flag('atm'),
      carWash: flag('carWash'),
      oilChange: flag('oilChange'),
      cardsAccepted: flag('cardsAccepted'),
      open24Hours: flag('open24Hours'),
    );
  }

  /// Only the known values, so nothing is written for "not listed".
  Map<String, bool> toMap() => {
    for (final MapEntry(:key, :value) in _byKey.entries) key: ?value,
  };

  Map<String, bool?> get _byKey => {
    'restroom': restroom,
    'accessibleRestroom': accessibleRestroom,
    'convenienceStore': convenienceStore,
    'airPump': airPump,
    'atm': atm,
    'carWash': carWash,
    'oilChange': oilChange,
    'cardsAccepted': cardsAccepted,
    'open24Hours': open24Hours,
  };

  /// True when at least one amenity is listed either way.
  bool get hasAny => _byKey.values.any((v) => v != null);
}

class StationModel {
  final String id;
  final String name;
  final String brand;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final double regularPrice;
  final double premiumPrice;
  final double dieselPrice;

  /// When prices were last reported. [epoch] when never (see [hasPrices]).
  final DateTime lastUpdated;

  /// Latest reported price per product, e.g. {"XCS": 61.2}; grades only
  /// (the three fields above) for stations reported before products.
  final Map<String, double> productPrices;

  final StationAmenities amenities;

  /// Weekday name to hours text, e.g. {"Monday": "5 AM to 9 PM"}. Empty
  /// when unknown; see [amenities.open24Hours] for round-the-clock.
  final Map<String, String> openingHours;
  final String phone;
  final String website;
  final String mapsUrl;

  /// Google rating out of 5 and how many reviews it rests on; null / 0
  /// when unrated.
  final double? rating;
  final int reviewCount;

  /// "operational", "temporarily_closed" or "permanently_closed".
  final String status;

  /// A convenience store next door (within 60 m) when the station has no
  /// store of its own, e.g. "7-Eleven".
  final String nearbyStore;

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
    this.city = '',
    this.productPrices = const {},
    this.amenities = StationAmenities.none,
    this.openingHours = const {},
    this.phone = '',
    this.website = '',
    this.mapsUrl = '',
    this.rating,
    this.reviewCount = 0,
    this.status = operational,
    this.nearbyStore = '',
  });

  static const operational = 'operational';

  /// [lastUpdated] for a station nobody has reported prices for yet.
  static final epoch = DateTime.fromMillisecondsSinceEpoch(0);

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

  /// True once any pump price has been reported.
  bool get hasPrices =>
      regularPrice > 0 ||
      premiumPrice > 0 ||
      dieselPrice > 0 ||
      productPrices.isNotEmpty;

  bool get isOpen => status == operational;

  /// True when the station has a place on the map ((0, 0) means none).
  bool get isPlaced => latitude != 0 || longitude != 0;

  factory StationModel.fromMap(Map<String, dynamic> data, String id) {
    return StationModel(
      id: id,
      name: data['name'] ?? 'Unknown Station',
      brand: data['brand'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      regularPrice: (data['regularPrice'] ?? 0.0).toDouble(),
      premiumPrice: (data['premiumPrice'] ?? 0.0).toDouble(),
      dieselPrice: (data['dieselPrice'] ?? 0.0).toDouble(),
      lastUpdated: parseDateTime(data['lastUpdated']),
      productPrices: _parseProductPrices(data['productPrices']),
      amenities: StationAmenities.fromMap(data['amenities']),
      openingHours: _parseHours(data['openingHours']),
      phone: data['phone'] is String ? data['phone'] : '',
      website: data['website'] is String ? data['website'] : '',
      mapsUrl: data['mapsUrl'] is String ? data['mapsUrl'] : '',
      rating: data['rating'] is num ? (data['rating'] as num).toDouble() : null,
      reviewCount: data['reviewCount'] is int ? data['reviewCount'] : 0,
      status: data['status'] is String ? data['status'] : operational,
      nearbyStore: data['nearbyStore'] is String ? data['nearbyStore'] : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'address': address,
      if (city.isNotEmpty) 'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'regularPrice': regularPrice,
      'premiumPrice': premiumPrice,
      'dieselPrice': dieselPrice,
      if (lastUpdated != epoch) 'lastUpdated': Timestamp.fromDate(lastUpdated),
      'productPrices': productPrices,
      if (amenities.hasAny) 'amenities': amenities.toMap(),
      if (openingHours.isNotEmpty) 'openingHours': openingHours,
      if (phone.isNotEmpty) 'phone': phone,
      if (website.isNotEmpty) 'website': website,
      if (mapsUrl.isNotEmpty) 'mapsUrl': mapsUrl,
      if (rating != null) 'rating': rating,
      if (reviewCount > 0) 'reviewCount': reviewCount,
      if (status != operational) 'status': status,
      if (nearbyStore.isNotEmpty) 'nearbyStore': nearbyStore,
    };
  }

  static Map<String, double> _parseProductPrices(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is num && value > 0) key: value.toDouble(),
    });
  }

  static Map<String, String> _parseHours(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is String) key: value,
    });
  }

  /// A Firestore [Timestamp], epoch milliseconds, or nothing ([epoch]).
  static DateTime parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return epoch;
  }
}
