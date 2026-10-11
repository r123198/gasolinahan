import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Someone away this long sees the welcome tour again.
const welcomeBackAfter = Duration(days: 30);

const _neverShowKey = 'onboarding_never_show';
const _lastOpenedKey = 'last_opened_at';

/// Show the welcome tour on first launch and after a long absence, unless
/// the user chose "Don't show this again".
bool shouldShowWelcome({
  required bool neverShow,
  DateTime? lastOpenedAt,
  required DateTime now,
}) {
  if (neverShow) return false;
  if (lastOpenedAt == null) return true;
  return now.difference(lastOpenedAt) > welcomeBackAfter;
}

/// Remembers launches and the welcome-tour opt-out on this device.
class OnboardingPrefs {
  /// Decides whether to show the welcome, then records this launch. Never
  /// throws: if storage fails the user goes straight on.
  Future<bool> checkAndRecordLaunch(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastOpenedKey);
      final show = shouldShowWelcome(
        neverShow: prefs.getBool(_neverShowKey) ?? false,
        lastOpenedAt: lastMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastMs),
        now: now,
      );
      await prefs.setInt(_lastOpenedKey, now.millisecondsSinceEpoch);
      return show;
    } on PlatformException catch (e) {
      debugPrint('Onboarding prefs unavailable: ${e.code}');
      return false;
    }
  }

  Future<void> neverShowAgain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_neverShowKey, true);
    } on PlatformException catch (e) {
      debugPrint('Could not save onboarding opt-out: ${e.code}');
    }
  }
}
