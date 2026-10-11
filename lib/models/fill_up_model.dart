import 'dart:convert';

/// One tank fill-up logged by the user.
class FillUp {
  final int? id;
  final String stationId;
  final String stationName;
  final String brand;
  final String fuelType;
  final double amountSpent;
  final double? liters;

  /// Pump price paid, in ₱/L. Null on fill-ups logged before it was asked.
  final double? pricePerLiter;
  final double odometerKm;
  final DateTime timestamp;
  final String notes;

  /// Receipt / pump photos, as paths inside the app's documents folder.
  /// Device-only: photos are not uploaded.
  final List<String> photoPaths;

  /// Firestore document id under users/{uid}/fill_ups; null until synced.
  final String? remoteId;

  /// Last change on any device; the newer side wins when syncing.
  final DateTime? updatedAt;

  /// Account that logged it on this device; null for rows saved before
  /// sign-in scoping, which the next signed-in user claims.
  final String? ownerUid;

  /// The brand's product, e.g. "XCS" or "Turbo Diesel"; [fuelType] is its
  /// grade. Null when only the grade was picked.
  final String? productName;

  /// Where it was logged (captured automatically, never displayed).
  final double? latitude;
  final double? longitude;

  /// Points this fill-up earned; taken back if it's deleted.
  final int pointsAwarded;

  const FillUp({
    this.id,
    required this.stationId,
    required this.stationName,
    required this.brand,
    required this.fuelType,
    required this.amountSpent,
    this.liters,
    this.pricePerLiter,
    required this.odometerKm,
    required this.timestamp,
    this.notes = '',
    this.photoPaths = const [],
    this.remoteId,
    this.updatedAt,
    this.ownerUid,
    this.productName,
    this.latitude,
    this.longitude,
    this.pointsAwarded = 0,
  });

  FillUp copyWith({
    int? id,
    List<String>? photoPaths,
    String? remoteId,
    DateTime? updatedAt,
    String? ownerUid,
    int? pointsAwarded,
  }) => FillUp(
    id: id ?? this.id,
    stationId: stationId,
    stationName: stationName,
    brand: brand,
    fuelType: fuelType,
    amountSpent: amountSpent,
    liters: liters,
    pricePerLiter: pricePerLiter,
    odometerKm: odometerKm,
    timestamp: timestamp,
    notes: notes,
    photoPaths: photoPaths ?? this.photoPaths,
    remoteId: remoteId ?? this.remoteId,
    updatedAt: updatedAt ?? this.updatedAt,
    ownerUid: ownerUid ?? this.ownerUid,
    productName: productName,
    latitude: latitude,
    longitude: longitude,
    pointsAwarded: pointsAwarded ?? this.pointsAwarded,
  );

  /// Price per liter as entered, or worked out from amount and liters.
  double? get effectivePricePerLiter {
    final price = pricePerLiter;
    if (price != null && price > 0) return price;
    final l = liters;
    if (l == null || l <= 0) return null;
    return amountSpent / l;
  }

  factory FillUp.fromMap(Map<String, dynamic> map) {
    final photos = map['photoPaths'] as String?;
    return FillUp(
      id: map['id'] as int?,
      stationId: (map['stationId'] ?? '') as String,
      stationName: (map['stationName'] ?? '') as String,
      brand: (map['brand'] ?? '') as String,
      fuelType: (map['fuelType'] ?? 'regular') as String,
      amountSpent: (map['amountSpent'] as num).toDouble(),
      liters: (map['liters'] as num?)?.toDouble(),
      pricePerLiter: (map['pricePerLiter'] as num?)?.toDouble(),
      odometerKm: (map['odometerKm'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      notes: (map['notes'] as String?) ?? '',
      photoPaths: photos == null || photos.isEmpty
          ? const []
          : List<String>.unmodifiable(jsonDecode(photos) as List),
      remoteId: map['remoteId'] as String?,
      updatedAt: _parseDate(map['updatedAt']),
      ownerUid: map['ownerUid'] as String?,
      productName: map['productName'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      pointsAwarded: (map['pointsAwarded'] as num?)?.toInt() ?? 0,
    );
  }

  /// A fill-up as stored in Firestore (no local id, owner or photos).
  factory FillUp.fromRemote(Map<String, dynamic> map, String docId) =>
      FillUp.fromMap({
        ...map,
        'id': null,
        'photoPaths': null,
        'ownerUid': null,
        'remoteId': docId,
      });

  Map<String, dynamic> toRemoteMap() => {
    'stationId': stationId,
    'stationName': stationName,
    'brand': brand,
    'fuelType': fuelType,
    'amountSpent': amountSpent,
    'liters': liters,
    'pricePerLiter': pricePerLiter,
    'odometerKm': odometerKm,
    'timestamp': timestamp.toIso8601String(),
    'notes': notes,
    'updatedAt': (updatedAt ?? timestamp).toIso8601String(),
    'productName': productName,
    'latitude': latitude,
    'longitude': longitude,
    'pointsAwarded': pointsAwarded,
  };

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'stationId': stationId,
      'stationName': stationName,
      'brand': brand,
      'fuelType': fuelType,
      'amountSpent': amountSpent,
      'liters': liters,
      'pricePerLiter': pricePerLiter,
      'odometerKm': odometerKm,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'photoPaths': jsonEncode(photoPaths),
      'remoteId': remoteId,
      'updatedAt': updatedAt?.toIso8601String(),
      'ownerUid': ownerUid,
      'productName': productName,
      'latitude': latitude,
      'longitude': longitude,
      'pointsAwarded': pointsAwarded,
    };
  }
}
