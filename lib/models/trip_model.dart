/// A saved drive. Route points are loaded separately when needed.
class Trip {
  final int? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;

  const Trip({
    this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
  });

  double get distanceKm => distanceMeters / 1000;
  Duration get duration => endedAt.difference(startedAt);

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as int?,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: DateTime.parse(map['endedAt'] as String),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
    );
  }
}
