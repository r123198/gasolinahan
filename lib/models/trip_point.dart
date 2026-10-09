/// One GPS sample. [speedMps] is null when the platform does not report it.
class TripPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speedMps;
  final double? accuracyMeters;

  const TripPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speedMps,
    this.accuracyMeters,
  });

  factory TripPoint.fromMap(Map<String, dynamic> map) {
    return TripPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      speedMps: (map['speedMps'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speedMps': speedMps,
      'accuracyMeters': accuracyMeters,
    };
  }
}
