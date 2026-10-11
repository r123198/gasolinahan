import '../services/geo.dart';
import 'station_model.dart';

/// Stations within this distance of the user count as "nearby".
const nearbyRadiusMeters = 30000.0;

/// Points (lat, lng) the map should fit on first open: the stations near
/// the user plus the user, or — when nothing is near (or there's no fix) —
/// every reported station, so the map never opens empty.
List<(double, double)> pointsToFrame(
  List<StationModel> stations, {
  double? userLat,
  double? userLng,
}) {
  final located = [
    for (final s in stations)
      if (s.latitude != 0 || s.longitude != 0) s,
  ];
  if (userLat != null && userLng != null) {
    final near = [
      for (final s in located)
        if (haversineMeters(userLat, userLng, s.latitude, s.longitude) <=
            nearbyRadiusMeters)
          s,
    ];
    if (near.isNotEmpty) {
      return [
        for (final s in near) (s.latitude, s.longitude),
        (userLat, userLng),
      ];
    }
  }
  return [for (final s in located) (s.latitude, s.longitude)];
}
