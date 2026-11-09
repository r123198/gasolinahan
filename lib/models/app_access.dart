/// Who can open what. The web's map is public and read-only: prices are only
/// reported from the phone apps. The rest of the web, and the whole of the
/// phone apps, needs an account.
const trackerTabIndex = 0;
const mapTabIndex = 1;
const accountTabIndex = 2;

/// What a guest was trying to do when they were asked to sign in, so signing
/// in carries on with it.
enum SignInGoal { tracker, account }

String startRouteFor({required bool isWeb, required bool isSignedIn}) =>
    isWeb || isSignedIn ? '/dashboard' : '/login';

String routeAfterSignOut({required bool isWeb}) =>
    isWeb ? '/dashboard' : '/login';

/// Only the web lets anyone in without an account.
bool isGuestVisitor({required bool isWeb, required bool isSignedIn}) =>
    isWeb && !isSignedIn;

/// The tour explains the phone app; on the web it would only hide the map.
bool showsWelcomeTour({required bool isWeb, required bool isDue}) =>
    !isWeb && isDue;

int initialDashboardTab({required bool isWeb, SignInGoal? goal}) =>
    switch (goal) {
      SignInGoal.tracker => trackerTabIndex,
      SignInGoal.account => accountTabIndex,
      null => isWeb ? mapTabIndex : trackerTabIndex,
    };

/// The goal behind a guest's tap on [tab]; null when it needs no account.
SignInGoal? signInGoalForTab(int tab) => switch (tab) {
  trackerTabIndex => SignInGoal.tracker,
  accountTabIndex => SignInGoal.account,
  _ => null,
};
