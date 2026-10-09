/// One tank fill-up logged by the user.
class FillUp {
  final int? id;
  final String stationId;
  final String stationName;
  final String brand;
  final String fuelType;
  final double amountSpent;
  final double? liters;
  final double odometerKm;
  final DateTime timestamp;

  const FillUp({
    this.id,
    required this.stationId,
    required this.stationName,
    required this.brand,
    required this.fuelType,
    required this.amountSpent,
    this.liters,
    required this.odometerKm,
    required this.timestamp,
  });

  factory FillUp.fromMap(Map<String, dynamic> map) {
    return FillUp(
      id: map['id'] as int?,
      stationId: (map['stationId'] ?? '') as String,
      stationName: (map['stationName'] ?? '') as String,
      brand: (map['brand'] ?? '') as String,
      fuelType: (map['fuelType'] ?? 'regular') as String,
      amountSpent: (map['amountSpent'] as num).toDouble(),
      liters: (map['liters'] as num?)?.toDouble(),
      odometerKm: (map['odometerKm'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
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
      'odometerKm': odometerKm,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
