import 'dart:io' show Platform;
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Tells the app when the phone itself senses you are in a vehicle (Android
/// Activity Recognition, iOS CoreMotion). Only a hint: trips still need GPS
/// movement to start.
abstract class DrivingActivitySource {
  /// Asks for permission and begins listening. Returns false when this phone
  /// cannot provide the signal.
  Future<bool> start();

  /// true = in a vehicle, false = still or on foot. Uncertain readings are
  /// not emitted.
  Stream<bool> get inVehicle;
}

const _minConfidence = 60;

class DeviceDrivingActivitySource implements DrivingActivitySource {
  @override
  Stream<bool> get inVehicle => ActivityRecognition()
      // The location service already keeps the app alive; a second
      // foreground notification would be redundant.
      .activityStream(runForegroundService: false)
      .where((e) => e.confidence >= _minConfidence)
      .map(_toVehicleSignal)
      .where((signal) => signal != null)
      .cast<bool>()
      .distinct();

  @override
  Future<bool> start() async {
    // iOS asks for motion access itself; permission_handler must not be used
    // for it there.
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return false;
    }
    return ActivityRecognition().isAvailable();
  }

  bool? _toVehicleSignal(ActivityEvent e) {
    return switch (e.type) {
      ActivityType.inVehicle => true,
      ActivityType.still ||
      ActivityType.walking ||
      ActivityType.onFoot ||
      ActivityType.running ||
      ActivityType.onBicycle => false,
      _ => null,
    };
  }
}
