import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/brand_registry.dart';
import '../models/station_naming.dart';
import 'geo.dart';

/// OpenStreetMap services (free; their policies ask for an identifying
/// User-Agent and light use — one lookup per opened form).
const _overpassUrl = 'https://overpass-api.de/api/interpreter';
const _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';
const _userAgent = 'Gasolinahan/1.0 (com.maalam.gasolinahan)';
const _timeout = Duration(seconds: 8);

/// How close a mapped station must be to count as "the one you're at".
const fuelStationRadiusMeters = 200;

/// What OpenStreetMap says about where the user is standing.
class PlaceGuess {
  /// Brand of the gas station here, when one is mapped and recognised.
  final BrandInfo? brand;

  /// Branch part of the station's name ("Mayapa" in "Petron Mayapa").
  final String? branch;

  /// Full mapped name, for independent stations with no known brand.
  final String? stationName;

  /// Barangay / suburb / town around the user.
  final String? area;
  final double? distanceMeters;

  const PlaceGuess({
    this.brand,
    this.branch,
    this.stationName,
    this.area,
    this.distanceMeters,
  });

  /// Best text for the "Branch or area" field.
  String? get branchOrArea => (branch?.isNotEmpty ?? false) ? branch : area;
}

/// The mapped gas station nearest to (lat, lng) in an Overpass response.
PlaceGuess? nearestFuelStation(
  Map<String, dynamic> json, {
  required double lat,
  required double lng,
}) {
  PlaceGuess? best;
  for (final e in (json['elements'] as List? ?? const [])) {
    if (e is! Map) continue;
    final center = e['center'] is Map ? e['center'] as Map : e;
    final eLat = (center['lat'] as num?)?.toDouble();
    final eLng = (center['lon'] as num?)?.toDouble();
    final tags = e['tags'] is Map ? e['tags'] as Map : const {};
    if (eLat == null || eLng == null) continue;
    final distance = haversineMeters(lat, lng, eLat, eLng);
    if (best != null && distance >= best.distanceMeters!) continue;

    final name = (tags['name'] as String?)?.trim() ?? '';
    final brandTag = (tags['brand'] as String?)?.trim() ?? '';
    final brand = BrandRegistry.match(
      brandTag,
      stationName: '$name ${tags['operator'] ?? ''}',
    );
    final branch = brand == null || name.isEmpty ? null : branchOf(name, brand);
    best = PlaceGuess(
      brand: brand,
      branch: branch == null || branch.isEmpty ? null : branch,
      stationName: name.isEmpty ? null : name,
      distanceMeters: distance,
    );
  }
  return best;
}

/// The most useful area name in a Nominatim reverse-geocode response.
String? areaName(Map<String, dynamic> json) {
  final address = json['address'];
  if (address is! Map) return null;
  for (final key in const [
    'suburb',
    'village',
    'quarter',
    'neighbourhood',
    'city_district',
    'town',
    'municipality',
    'city',
  ]) {
    final value = (address[key] as String?)?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Looks up the gas station / area at a position. Never throws: any
/// failure (offline, slow, rate-limited) just means no guess.
class PlaceLookup {
  final http.Client _client;

  PlaceLookup({http.Client? client}) : _client = client ?? http.Client();

  Future<PlaceGuess?> lookUp(double lat, double lng) async {
    final station = await _nearestStation(lat, lng);
    if (station?.branchOrArea != null) return station;
    final area = await _area(lat, lng);
    if (station == null && area == null) return null;
    return PlaceGuess(
      brand: station?.brand,
      branch: station?.branch,
      stationName: station?.stationName,
      distanceMeters: station?.distanceMeters,
      area: area,
    );
  }

  Future<PlaceGuess?> _nearestStation(double lat, double lng) async {
    final query =
        '[out:json][timeout:8];'
        'nwr(around:$fuelStationRadiusMeters,$lat,$lng)[amenity=fuel];'
        'out center tags;';
    final json = await _getJson(
      _client.post(
        Uri.parse(_overpassUrl),
        headers: {'User-Agent': _userAgent},
        body: {'data': query},
      ),
    );
    return json == null ? null : nearestFuelStation(json, lat: lat, lng: lng);
  }

  Future<String?> _area(double lat, double lng) async {
    final uri = Uri.parse(_nominatimUrl).replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'zoom': '16',
        'addressdetails': '1',
      },
    );
    final json = await _getJson(
      _client.get(uri, headers: {'User-Agent': _userAgent}),
    );
    return json == null ? null : areaName(json);
  }

  Future<Map<String, dynamic>?> _getJson(Future<http.Response> request) async {
    try {
      final response = await request.timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> ? body : null;
    } on Exception catch (e) {
      debugPrint('OpenStreetMap lookup failed: $e');
      return null;
    }
  }
}
