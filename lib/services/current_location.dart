import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart';

/// A fresh fix is this old at most; anything older is only a fallback.
const _freshFixAge = Duration(minutes: 2);
const _defaultTimeout = Duration(seconds: 10);

/// Where the phone is, from a one-off lookup.
class GeoFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  /// True when it came from the phone's cache rather than a new reading.
  final bool isStale;

  const GeoFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters = 0,
    this.isStale = false,
  });
}

/// Reads the phone's location once, or null when it can't.
typedef LocateOnce = Future<GeoFix?> Function();

/// One-off "where am I right now", for the map, the fill-up form and price
/// reports. Separate from the trip stream (the `location` plugin), whose
/// battery-saving settings — a 30 m distance filter and 10 s interval —
/// make its one-shot lookups slow or silent while the car is parked.
///
/// Never prompts for permission; callers ask first. Returns null when
/// location is off, not allowed, or no fix arrives within [timeout]; a
/// recent cached fix is used before giving up.
Future<GeoFix?> readCurrentLocation({
  Duration timeout = _defaultTimeout,
}) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _toFix(position);
    } on TimeoutException {
      debugPrint('Current location timed out; trying the last known fix');
    } on LocationServiceDisabledException {
      return null;
    }
    return readLastKnownLocation(maxAge: null);
  } on PermissionDeniedException {
    return null;
  } on PlatformException catch (e) {
    debugPrint('Current location failed: ${e.code}');
    return null;
  }
}

/// The phone's cached fix, instantly. Null when there is none, or it is
/// older than [maxAge] (null = any age).
Future<GeoFix?> readLastKnownLocation({Duration? maxAge = _freshFixAge}) async {
  try {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final age = DateTime.now().difference(position.timestamp);
    if (maxAge != null && age > maxAge) return null;
    return _toFix(position, isStale: age > _freshFixAge);
  } on PermissionDeniedException {
    return null;
  } on PlatformException catch (e) {
    debugPrint('Last known location failed: ${e.code}');
    return null;
  }
}

GeoFix _toFix(Position p, {bool isStale = false}) => GeoFix(
  latitude: p.latitude,
  longitude: p.longitude,
  accuracyMeters: p.accuracy,
  isStale: isStale,
);
