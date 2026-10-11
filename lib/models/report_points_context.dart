import '../services/geo.dart';
import 'brand_registry.dart';
import 'points_rules.dart';
import 'price_freshness.dart';

/// A report counts as "at the station" within this distance of it.
const reportStationRadiusMeters = 200.0;

/// A grade price this far from nearby stations' median is held for review.
const outlierThreshold = 0.15;

/// Nearby prices needed before a price can be called unusual.
const minNearbyPricesForOutlier = 3;

/// The station being reported, as already known to the app.
class ReportedStationInfo {
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;

  const ReportedStationInfo({
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
  });
}

/// One of the user's earlier reports.
class PastReport {
  final String stationId;
  final DateTime timestamp;
  final int pointsAwarded;

  const PastReport({
    required this.stationId,
    required this.timestamp,
    required this.pointsAwarded,
  });

  bool get wasRewarded => pointsAwarded > 0;
}

/// Everything known when a report is submitted.
class ReportPointsInput {
  final String stationId;
  final Map<String, double> productPrices;
  final Map<FuelCategory, double> gradePrices;
  final bool hasPhoto;

  /// Null (or 0, 0) when the location is unknown.
  final double? userLat;
  final double? userLng;

  /// Null for a station the app didn't know yet.
  final ReportedStationInfo? existingStation;

  /// Grade prices at other nearby stations, for spotting unusual prices.
  final List<Map<FuelCategory, double>> nearbyGradePrices;

  /// The user's earlier reports; null when they couldn't be loaded.
  final List<PastReport>? history;
  final DateTime now;

  const ReportPointsInput({
    required this.stationId,
    required this.productPrices,
    required this.gradePrices,
    required this.hasPhoto,
    required this.userLat,
    required this.userLng,
    required this.existingStation,
    required this.nearbyGradePrices,
    required this.history,
    required this.now,
  });
}

/// Turns what's known about a report into the facts [pointsForReport] uses.
ReportContext buildReportContext(ReportPointsInput r) {
  final station = r.existingStation;
  final firstAfterChange =
      station != null && pricesMayHaveChanged(station.lastUpdated, r.now);
  final history = r.history;
  final rewarded = history?.where((p) => p.wasRewarded).toList() ?? const [];
  final rewardedToday = rewarded
      .where((p) => _sameDay(p.timestamp, r.now))
      .toList();

  return ReportContext(
    productCount: _pricedCount(r),
    hasPhoto: r.hasPhoto,
    isAtStation: _isAtStation(r),
    isNewStation: station == null,
    isFirstAfterPriceChange: firstAfterChange,
    isConfirmation:
        station != null &&
        !firstAfterChange &&
        _sameDay(station.lastUpdated, r.now),
    alreadyRewardedStationToday: rewardedToday.any(
      (p) => p.stationId == r.stationId,
    ),
    rewardedReportsToday: rewardedToday.length,
    isOutlier: _isOutlier(r),
    streakWeeks: streakWeeksBefore(rewarded.map((p) => p.timestamp), r.now),
    isFirstReport: history != null && rewarded.isEmpty,
  );
}

/// "Price report +3, 2 prices +2" — stored with the award for auditing.
String describeAward(ReportContext context) {
  final award = pointsForReport(context);
  if (award.lines.isEmpty) return award.reason ?? '';
  return award.lines
      .map((l) => '${l.label} ${l.points >= 0 ? '+' : ''}${l.points}')
      .join(', ');
}

int _pricedCount(ReportPointsInput r) {
  final products = r.productPrices.values.where((p) => p > 0).length;
  if (products > 0) return products;
  return r.gradePrices.values.where((p) => p > 0).length;
}

bool _isAtStation(ReportPointsInput r) {
  final lat = r.userLat;
  final lng = r.userLng;
  if (lat == null || lng == null || (lat == 0 && lng == 0)) return false;
  final station = r.existingStation;
  if (station == null || (station.latitude == 0 && station.longitude == 0)) {
    return true; // the report itself places the station here
  }
  return haversineMeters(lat, lng, station.latitude, station.longitude) <=
      reportStationRadiusMeters;
}

bool _isOutlier(ReportPointsInput r) {
  for (final MapEntry(key: grade, value: price) in r.gradePrices.entries) {
    if (price <= 0) continue;
    final nearby = [
      for (final s in r.nearbyGradePrices)
        if ((s[grade] ?? 0) > 0) s[grade]!,
    ];
    if (nearby.length < minNearbyPricesForOutlier) continue;
    final median = _median(nearby);
    if ((price - median).abs() / median > outlierThreshold) return true;
  }
  return false;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
