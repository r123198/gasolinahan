import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'auto_tracking_allowed';

/// The user's answer to the automatic trip tracking disclosure. Background
/// location and activity recognition stay off until it is true.
abstract interface class TrackingConsentStore {
  /// null when the user has never been asked.
  Future<bool?> read();

  Future<void> write(bool allowed);

  /// Forgets the answer, so the disclosure shows again.
  Future<void> clear();
}

class PrefsTrackingConsentStore implements TrackingConsentStore {
  @override
  Future<bool?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key);
    } on PlatformException catch (e) {
      // Unreadable counts as "not asked": tracking stays off.
      debugPrint('Tracking consent unavailable: ${e.code}');
      return null;
    }
  }

  @override
  Future<void> write(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, allowed);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
