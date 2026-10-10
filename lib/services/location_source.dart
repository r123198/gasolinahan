import 'package:location/location.dart';
import '../models/trip_point.dart';

/// Where GPS samples come from. Abstracted so the view model can be tested
/// without a device.
abstract class LocationSource {
  /// Requests permissions and starts the sample stream. Returns false when the
  /// user has not allowed location.
  Future<bool> start();

  Stream<TripPoint> get points;

  /// Sample often while driving, sparingly while waiting, to save battery.
  Future<void> setPrecise(bool precise);
}

class DeviceLocationSource implements LocationSource {
  final Location _location = Location();

  @override
  Stream<TripPoint> get points => _location.onLocationChanged
      .where((d) => d.latitude != null && d.longitude != null)
      .map(_toPoint);

  @override
  Future<bool> start() async {
    var enabled = await _location.serviceEnabled();
    if (!enabled) enabled = await _location.requestService();
    if (!enabled) return false;

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    final allowed =
        permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
    if (!allowed) return false;

    await setPrecise(false);
    try {
      await _location.enableBackgroundMode(enable: true);
    } catch (_) {
      // Background mode needs "Always" permission; foreground still works.
    }
    return true;
  }

  @override
  Future<void> setPrecise(bool precise) {
    return _location.changeSettings(
      accuracy: precise ? LocationAccuracy.high : LocationAccuracy.balanced,
      interval: precise ? 3000 : 10000,
      distanceFilter: precise ? 10 : 30,
    );
  }

  TripPoint _toPoint(LocationData d) {
    final millis = d.time;
    return TripPoint(
      latitude: d.latitude!,
      longitude: d.longitude!,
      timestamp: millis == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(millis.round()),
      speedMps: d.speed,
      accuracyMeters: d.accuracy,
    );
  }
}
