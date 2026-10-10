import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/station_model.dart';

/// Shows "Did you fill up here?" notifications and reports taps on them.
abstract class NudgeNotifier {
  Future<void> init({required void Function(String stationId) onTap});
  Future<void> showFillUpNudge(StationModel station);

  /// The station id when the app was opened by tapping a nudge, else null.
  Future<String?> launchStationId();
}

const _channelId = 'fill_up_nudges';
const _channelName = 'Fill-up reminders';
const _channelDescription =
    'Asks whether you filled up when you stop at a gas station.';

class DeviceNudgeNotifier implements NudgeNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> init({required void Function(String stationId) onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final stationId = response.payload;
        if (stationId != null && stationId.isNotEmpty) onTap(stationId);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> showFillUpNudge(StationModel station) {
    return _plugin.show(
      id: station.id.hashCode & 0x7fffffff,
      title: 'Fill-up at ${station.name}?',
      body: 'Tap to log what you spent and your odometer.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: station.id,
    );
  }

  @override
  Future<String?> launchStationId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}
