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
  final List<String> photoPaths;

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
  });

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
    );
  }

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
    };
  }
}
