import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:location/location.dart';

import '../models/station_model.dart';
import '../services/geo.dart';
import '../services/place_lookup.dart';

const _locationTimeout = Duration(seconds: 8);

/// A reported station this close counts as "the one you're at".
const reportedStationRadiusMeters = 150.0;

/// Where the user is as the fill-up form opens, and what's there.
class FillUpLocationGuess {
  final double latitude;
  final double longitude;

  /// A station from the app's own price reports, when one is right here.
  final StationModel? reportedStation;

  /// What OpenStreetMap knows about this spot (station brand / area).
  final PlaceGuess? place;

  const FillUpLocationGuess({
    required this.latitude,
    required this.longitude,
    this.reportedStation,
    this.place,
  });
}

/// The reported station within [reportedStationRadiusMeters] of the user.
StationModel? reportedStationAt(
  List<StationModel> stations,
  double lat,
  double lng,
) {
  StationModel? best;
  var bestDistance = reportedStationRadiusMeters;
  for (final s in stations) {
    if (s.latitude == 0 && s.longitude == 0) continue;
    final d = haversineMeters(lat, lng, s.latitude, s.longitude);
    if (d <= bestDistance) {
      best = s;
      bestDistance = d;
    }
  }
  return best;
}

/// Finds the user, then what station or area they're at. Null when the
/// location can't be read (off, denied, or no fix in time) — the form then
/// just works as before.
Future<FillUpLocationGuess?> guessFillUpLocation({
  required List<StationModel> reportedStations,
  Location? location,
  PlaceLookup? lookup,
}) async {
  final LocationData fix;
  try {
    final loc = location ?? Location();
    final permission = await loc.hasPermission();
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      return null; // never prompt from inside the form
    }
    fix = await loc.getLocation().timeout(_locationTimeout);
  } on TimeoutException {
    return null;
  } on PlatformException catch (e) {
    debugPrint('Fill-up location unavailable: ${e.code}');
    return null;
  }
  final lat = fix.latitude;
  final lng = fix.longitude;
  if (lat == null || lng == null) return null;

  final reported = reportedStationAt(reportedStations, lat, lng);
  return FillUpLocationGuess(
    latitude: lat,
    longitude: lng,
    reportedStation: reported,
    place: reported == null
        ? await (lookup ?? PlaceLookup()).lookUp(lat, lng)
        : null,
  );
}
