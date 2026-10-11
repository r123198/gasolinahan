import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/services/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 11, 9);

  group('shouldShowWelcome', () {
    test('shows on the very first launch', () {
      expect(shouldShowWelcome(neverShow: false, now: now), isTrue);
    });

    test('hides for someone who opened the app recently', () {
      expect(
        shouldShowWelcome(
          neverShow: false,
          lastOpenedAt: now.subtract(const Duration(days: 3)),
          now: now,
        ),
        isFalse,
      );
    });

    test('shows again after a long absence', () {
      expect(
        shouldShowWelcome(
          neverShow: false,
          lastOpenedAt: now.subtract(
            welcomeBackAfter + const Duration(days: 1),
          ),
          now: now,
        ),
        isTrue,
      );
    });

    test('never shows once the user opted out', () {
      expect(shouldShowWelcome(neverShow: true, now: now), isFalse);
    });
  });

  group('OnboardingPrefs', () {
    test('first launch shows the welcome and records the open', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = OnboardingPrefs();
      expect(await prefs.checkAndRecordLaunch(now), isTrue);
      // The same day, it no longer shows.
      expect(await prefs.checkAndRecordLaunch(now), isFalse);
    });

    test('neverShowAgain is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = OnboardingPrefs();
      await prefs.neverShowAgain();
      final later = now.add(const Duration(days: 400));
      expect(await prefs.checkAndRecordLaunch(later), isFalse);
    });
  });
}
