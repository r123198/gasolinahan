import '../services/geo.dart';
import 'brand_registry.dart';
import 'station_model.dart';

/// Meters from the user to [station], or null without a fix or when the
/// station has no coordinates ((0, 0) means "not placed").
double? distanceToStation(StationModel station, double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (station.latitude == 0 && station.longitude == 0) return null;
  return haversineMeters(lat, lng, station.latitude, station.longitude);
}

/// [stations] closest to the user first. Stations without coordinates go
/// last, in their original order. Without a fix the order is unchanged.
List<StationModel> nearestFirst(
  List<StationModel> stations, {
  double? userLat,
  double? userLng,
}) {
  if (userLat == null || userLng == null) return List.of(stations);
  final placed = <(double, StationModel)>[];
  final unplaced = <StationModel>[];
  for (final s in stations) {
    final d = distanceToStation(s, userLat, userLng);
    if (d == null) {
      unplaced.add(s);
    } else {
      placed.add((d, s));
    }
  }
  placed.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, s) in placed) s, ...unplaced];
}

/// Brand names found among [stations], most common first, then by name.
/// Names are the registry's spelling where the brand is known, so "SeaOil"
/// and "Seaoil" count as one chip; blank brands are skipped.
List<String> brandsAmong(List<StationModel> stations) {
  final counts = <String, int>{};
  for (final s in stations) {
    final raw = s.brand.trim();
    final name = BrandRegistry.match(raw, stationName: s.name)?.name ?? raw;
    if (name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final names = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return names;
}

/// Quick filters on what a station offers, for the search page's chips.
enum StationFilter {
  restroom('Restroom'),
  open24Hours('Open 24 hours'),
  convenienceStore('Convenience store'),
  airPump('Air pump'),
  carWash('Car wash');

  final String label;
  const StationFilter(this.label);

  bool matches(StationModel s) => switch (this) {
    restroom => s.amenities.restroom == true,
    open24Hours => s.amenities.open24Hours == true,
    convenienceStore =>
      s.amenities.convenienceStore == true || s.nearbyStore.isNotEmpty,
    airPump => s.amenities.airPump == true,
    carWash => s.amenities.carWash == true,
  };
}

/// [stations] that offer everything in [filters].
List<StationModel> applyFilters(
  List<StationModel> stations,
  Set<StationFilter> filters,
) {
  if (filters.isEmpty) return stations;
  return [
    for (final s in stations)
      if (filters.every((f) => f.matches(s))) s,
  ];
}

/// How many recent searches are kept.
const maxRecentSearches = 8;

/// [current] with [query] moved to the front (case-insensitive, trimmed),
/// capped at [maxRecentSearches]. A blank query leaves the list as is.
List<String> pushRecentSearch(List<String> current, String query) {
  final q = query.trim();
  if (q.isEmpty) return List.of(current);
  final rest = [
    for (final c in current)
      if (c.toLowerCase() != q.toLowerCase()) c,
  ];
  return [q, ...rest].take(maxRecentSearches).toList();
}
