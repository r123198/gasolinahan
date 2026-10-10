import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

/// Compass heading for the map's location dot.
///
/// The iOS Simulator has no rotation sensor, and the sensor plugin reports
/// `NO_SENSOR` as an error the moment anything listens, so there the dot
/// simply has no heading cone. Real devices get the live compass.
Stream<LocationMarkerHeading?> headingStreamForDevice() {
  if (_isIosSimulator) return Stream.value(null);
  return const LocationMarkerDataStreamFactory()
      .fromRotationSensorHeadingStream();
}

bool get _isIosSimulator =>
    !kIsWeb &&
    Platform.isIOS &&
    Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
