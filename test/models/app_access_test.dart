import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/app_access.dart';

void main() {
  group('startRouteFor', () {
    test('the web always opens on the map, signed in or not', () {
      expect(startRouteFor(isWeb: true, isSignedIn: false), '/dashboard');
      expect(startRouteFor(isWeb: true, isSignedIn: true), '/dashboard');
    });

    test('the phone apps still require signing in first', () {
      expect(startRouteFor(isWeb: false, isSignedIn: false), '/login');
      expect(startRouteFor(isWeb: false, isSignedIn: true), '/dashboard');
    });
  });

  group('routeAfterSignOut', () {
    test('the web returns to the public map', () {
      expect(routeAfterSignOut(isWeb: true), '/dashboard');
    });

    test('the phone apps return to sign in', () {
      expect(routeAfterSignOut(isWeb: false), '/login');
    });
  });

  group('isGuestVisitor', () {
    test('only a signed-out web visitor is a guest', () {
      expect(isGuestVisitor(isWeb: true, isSignedIn: false), isTrue);
      expect(isGuestVisitor(isWeb: true, isSignedIn: true), isFalse);
      expect(isGuestVisitor(isWeb: false, isSignedIn: false), isFalse);
      expect(isGuestVisitor(isWeb: false, isSignedIn: true), isFalse);
    });
  });

  group('showsWelcomeTour', () {
    test('never covers the map on the web', () {
      expect(showsWelcomeTour(isWeb: true, isDue: true), isFalse);
    });

    test('follows the launch history on the phone apps', () {
      expect(showsWelcomeTour(isWeb: false, isDue: true), isTrue);
      expect(showsWelcomeTour(isWeb: false, isDue: false), isFalse);
    });
  });

  group('initialDashboardTab', () {
    test('the web lands on the map', () {
      expect(initialDashboardTab(isWeb: true), mapTabIndex);
    });

    test('the phone apps keep landing on the tracker', () {
      expect(initialDashboardTab(isWeb: false), trackerTabIndex);
    });

    test('signing in returns to the tab that asked for it', () {
      expect(
        initialDashboardTab(isWeb: true, goal: SignInGoal.tracker),
        trackerTabIndex,
      );
      expect(
        initialDashboardTab(isWeb: true, goal: SignInGoal.account),
        accountTabIndex,
      );
    });
  });

  group('signInGoalForTab', () {
    test('maps the signed-in tabs to their goals', () {
      expect(signInGoalForTab(trackerTabIndex), SignInGoal.tracker);
      expect(signInGoalForTab(accountTabIndex), SignInGoal.account);
    });

    test('the map needs no sign-in, so it has no goal', () {
      expect(signInGoalForTab(mapTabIndex), isNull);
    });
  });
}
