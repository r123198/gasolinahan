import 'dart:convert';
import 'dart:math' as math;

import 'report_points_context.dart';

/// One price report on its way to Firestore, whether sent straight from the
/// form or later from the offline queue (pending_reports).
class ReportUpload {
  /// Fixed before the first attempt, so a retry writes the same documents
  /// (and Firestore rules reject it) instead of a duplicate.
  final String reportId;
  final String userId;
  final String stationId;
  final String stationName;
  final String brand;
  final double latitude;
  final double longitude;
  final double regularPrice;
  final double premiumPrice;
  final double dieselPrice;
  final Map<String, double> productPrices;

  /// When the report was made; null means "now" (server time).
  final DateTime? timestamp;
  final int points;
  final String pointsReason;

  /// Unusual prices wait for review, and their points with them.
  final bool isPending;

  const ReportUpload({
    required this.reportId,
    required this.userId,
    required this.stationId,
    this.stationName = '',
    this.brand = '',
    this.latitude = 0,
    this.longitude = 0,
    this.regularPrice = 0,
    this.premiumPrice = 0,
    this.dieselPrice = 0,
    this.productPrices = const {},
    this.timestamp,
    this.points = 0,
    this.pointsReason = '',
    this.isPending = false,
  });

  /// A queued pending_reports row, uploaded as [uid].
  factory ReportUpload.fromPendingRow(
    Map<String, dynamic> row, {
    required String uid,
  }) {
    double price(String key) => (row[key] as num?)?.toDouble() ?? 0;
    return ReportUpload(
      reportId: pendingReportDocId(row, uid: uid),
      userId: uid,
      stationId: (row['stationId'] as String?) ?? '',
      stationName: (row['stationName'] as String?) ?? '',
      brand: (row['brand'] as String?) ?? '',
      latitude: price('latitude'),
      longitude: price('longitude'),
      regularPrice: price('regularPrice'),
      premiumPrice: price('premiumPrice'),
      dieselPrice: price('dieselPrice'),
      productPrices: decodeProductPrices(row['productPrices']),
      timestamp: DateTime.tryParse((row['timestamp'] as String?) ?? ''),
      points: pointsOf(row),
      pointsReason: (row['pointsReason'] as String?) ?? '',
      isPending: row['isPending'] == 1,
    );
  }

  int get awardedPoints => isPending ? 0 : points;
  String get status => isPending ? 'pending' : 'accepted';

  /// The reports/{reportId} document, minus its timestamp.
  Map<String, dynamic> reportFields() => {
    'userId': userId,
    'stationId': stationId,
    'reportedRegularPrice': regularPrice,
    'reportedPremiumPrice': premiumPrice,
    'reportedDieselPrice': dieselPrice,
    'reportedProductPrices': productPrices,
    'pointsAwarded': awardedPoints,
    'pointsReason': pointsReason,
    'status': status,
  };

  /// Station fields this report changes, minus lastUpdated. Name, brand and
  /// position only describe a station the report creates: an existing one
  /// keeps its own, so a mistaken pick can't rename or move it.
  Map<String, dynamic> stationFields({required bool stationExists}) => {
    if (regularPrice > 0) 'regularPrice': regularPrice,
    if (premiumPrice > 0) 'premiumPrice': premiumPrice,
    if (dieselPrice > 0) 'dieselPrice': dieselPrice,
    // set(merge: true) merges nested maps, so products missing from this
    // report keep their last price.
    if (productPrices.isNotEmpty) 'productPrices': productPrices,
    if (!stationExists) ...{
      if (stationName.isNotEmpty) 'name': stationName,
      if (brand.isNotEmpty) 'brand': brand,
      if (latitude != 0) 'latitude': latitude,
      if (longitude != 0) 'longitude': longitude,
    },
  };

  /// What the report adds to the user's own history (points preview).
  PastReport toPastReport() => PastReport(
    stationId: stationId,
    timestamp: timestamp ?? DateTime.now(),
    pointsAwarded: awardedPoints,
  );
}

/// Report doc id for a queued row: the id of the online attempt it replaces
/// when there was one, else one derived from the row (the timestamp keeps a
/// reinstalled app's reused row ids apart).
String pendingReportDocId(Map<String, dynamic> row, {required String uid}) {
  final remoteId = row['remoteId'];
  if (remoteId is String && remoteId.isNotEmpty) return remoteId;
  final at = DateTime.tryParse((row['timestamp'] as String?) ?? '');
  return 'pending_${uid}_${row['id']}_${at?.millisecondsSinceEpoch ?? 0}';
}

/// Points stored on a pending report row (0 for rows saved before points).
int pointsOf(Map<String, dynamic> report) {
  final value = report['pointsAwarded'];
  return value is int ? value : 0;
}

/// Reads the pending_reports.productPrices JSON column; bad data → empty.
Map<String, double> decodeProductPrices(Object? raw) {
  if (raw is! String || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && value is num && value > 0) key: value.toDouble(),
    };
  } on FormatException {
    return const {};
  }
}

/// Latitude/longitude box around a point, for "stations near me" queries:
/// Firestore filters the latitude range, [contains] the rest.
class GeoBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const GeoBox(this.minLat, this.maxLat, this.minLng, this.maxLng);

  /// A box reaching at least [radiusMeters] from ([lat], [lng]) each way.
  factory GeoBox.around(double lat, double lng, double radiusMeters) {
    const metersPerDegree = 111320.0;
    final dLat = radiusMeters / metersPerDegree;
    // Longitude degrees shrink towards the poles; clamp to stay finite.
    final cosLat = math.cos(lat * math.pi / 180).clamp(0.01, 1.0);
    final dLng = radiusMeters / (metersPerDegree * cosLat);
    return GeoBox(lat - dLat, lat + dLat, lng - dLng, lng + dLng);
  }

  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}
