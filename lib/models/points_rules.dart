/// Gasolinahan points: what each action earns.
///
/// Price reports earn the most: they help everyone, and can be checked
/// against location, photos and other reports. Fill-ups are self-reported
/// and can't be verified, so they earn little and are capped. Bonuses
/// reward consistency and better driving, not volume.
///
/// Before points can be exchanged for partner rewards, these rules must run
/// on the server (a Cloud Function or equivalent): anything awarded by the
/// app itself can be forged by a modified app.
library;

// Deliberately small numbers: single-digit awards make every point feel
// earned, and tiers sit far enough away that reaching one takes steady
// reporting (an active driver earns ~70 a month; Silver takes 2–3 months,
// Gold about a year, Platinum is a long-term badge).

// Price reports.
const reportBase = 3;
const reportPerProduct = 1;
const reportMaxProductsCounted = 4;
const reportFirstAfterPriceChange = 4;
const reportNewStation = 3;
const reportConfirmation = 1;
const reportNoPhotoFactor = 0.5;
const maxRewardedReportsPerDay = 10;

/// Paid later to the original reporter when someone confirms their prices.
const reportVerifiedBonus = 1;

/// +1 per consecutive week with a rewarded report, capped; missing a week
/// starts the streak over.
const maxWeeklyStreakBonus = 5;

// Fill-ups.
const fillUpBase = 1;
const fillUpCompleteBonus = 1;
const maxRewardedFillUpsPerDay = 2;
const maxRewardedFillUpsPerMonth = 20;

// Monthly bonuses.
const monthlyLoggingMinFillUps = 4;
const monthlyLoggingPoints = 3;
const efficiencyGainThreshold = 0.05;
const efficiencyGainMinTanks = 3;
const efficiencyGainPoints = 4;

/// Lifetime points at which each tier starts.
const tierThresholds = {
  PointsTier.bronze: 0,
  PointsTier.silver: 150,
  PointsTier.gold: 750,
  PointsTier.platinum: 2500,
};

/// Points expire this long after they're earned (keeps partner liability
/// bounded once points can be redeemed).
const pointsLifetime = Duration(days: 365);

enum PointsTier {
  bronze('Bronze'),
  silver('Silver'),
  gold('Gold'),
  platinum('Platinum');

  const PointsTier(this.label);
  final String label;
}

/// One-time head starts: early, visible progress makes people far more
/// likely to keep going.
enum Milestone {
  firstFillUp(2),
  firstReport(5),
  profileComplete(1),

  /// A referred friend gets 3 reports accepted.
  referralActivated(15);

  const Milestone(this.points);
  final int points;
}

/// One reason in an award, e.g. "Base" +20.
class PointsLine {
  final String label;
  final int points;

  const PointsLine(this.label, this.points);
}

class PointsAward {
  final List<PointsLine> lines;

  /// Why nothing was earned, when [points] is 0.
  final String? reason;

  /// Held for review instead of paid (e.g. an unusual price).
  final bool isPending;

  const PointsAward(this.lines, {this.reason, this.isPending = false});

  const PointsAward.none(String this.reason, {this.isPending = false})
    : lines = const [];

  int get points => lines.fold(0, (sum, l) => sum + l.points);
}

/// Facts about a price report, checked before it's submitted.
class ReportContext {
  final int productCount;
  final bool hasPhoto;

  /// Within the station radius when submitting.
  final bool isAtStation;

  /// No report for this station since this week's Tuesday price change.
  final bool isFirstAfterPriceChange;

  /// The station wasn't on the map yet.
  final bool isNewStation;

  /// Someone already reported this station today; this one confirms it.
  final bool isConfirmation;
  final bool alreadyRewardedStationToday;
  final int rewardedReportsToday;

  /// A price more than 15% away from nearby stations' median.
  final bool isOutlier;

  /// Consecutive weeks (before this one) with a rewarded report.
  final int streakWeeks;

  /// The user's first ever rewarded report.
  final bool isFirstReport;

  const ReportContext({
    required this.productCount,
    this.hasPhoto = true,
    this.isAtStation = true,
    this.isFirstAfterPriceChange = false,
    this.isNewStation = false,
    this.isConfirmation = false,
    this.alreadyRewardedStationToday = false,
    this.rewardedReportsToday = 0,
    this.isOutlier = false,
    this.streakWeeks = 0,
    this.isFirstReport = false,
  });
}

PointsAward pointsForReport(ReportContext r) {
  if (!r.isAtStation) {
    return const PointsAward.none('Report from the station to earn points');
  }
  if (r.alreadyRewardedStationToday) {
    return const PointsAward.none('Already rewarded for this station today');
  }
  if (r.rewardedReportsToday >= maxRewardedReportsPerDay) {
    return const PointsAward.none('Daily report limit reached');
  }
  if (r.isOutlier) {
    return const PointsAward.none(
      'Prices look unusual; points come after review',
      isPending: true,
    );
  }
  if (r.isConfirmation) {
    return const PointsAward([
      PointsLine('Confirmed prices', reportConfirmation),
    ]);
  }

  final products = r.productCount.clamp(0, reportMaxProductsCounted);
  final lines = [
    const PointsLine('Price report', reportBase),
    if (products > 0)
      PointsLine(
        products == 1 ? '1 price' : '$products prices',
        products * reportPerProduct,
      ),
    if (r.isFirstAfterPriceChange)
      const PointsLine('First after Tuesday', reportFirstAfterPriceChange),
    if (r.isNewStation) const PointsLine('New station', reportNewStation),
  ];
  if (!r.hasPhoto) {
    final full = lines.fold(0, (sum, l) => sum + l.points);
    final halved = (full * reportNoPhotoFactor).floor();
    lines.add(PointsLine('No photo (half)', halved - full));
  }
  // Streak and first-report bonuses aren't halved: they reward showing up.
  final streak = weeklyStreakBonus(r.streakWeeks);
  return PointsAward([
    ...lines,
    if (streak > 0) PointsLine('${r.streakWeeks + 1}-week streak', streak),
    if (r.isFirstReport)
      PointsLine('First report', Milestone.firstReport.points),
  ]);
}

/// Bonus for keeping a weekly reporting streak going: +1 for each earlier
/// consecutive week, up to [maxWeeklyStreakBonus].
int weeklyStreakBonus(int previousWeeks) =>
    previousWeeks.clamp(0, maxWeeklyStreakBonus);

/// Consecutive weeks (Mon–Sun) before the current one that have at least
/// one rewarded report. A gap ends the streak.
int streakWeeksBefore(Iterable<DateTime> rewardedReports, DateTime now) {
  DateTime weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
  final weeks = {for (final d in rewardedReports) weekStart(d)};
  var cursor = weekStart(now);
  var count = 0;
  while (true) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    if (!weeks.contains(cursor)) return count;
    count++;
  }
}

/// Facts about a logged fill-up.
class FillUpContext {
  /// Has price per liter, product and odometer.
  final bool isComplete;

  /// Odometer is above the previous fill-up's.
  final bool odometerConsistent;
  final int rewardedToday;
  final int rewardedThisMonth;
  final bool isFirstFillUp;

  /// Fill-ups already logged this calendar month (before this one).
  final int fillUpsThisMonth;

  const FillUpContext({
    this.isComplete = true,
    this.odometerConsistent = true,
    this.rewardedToday = 0,
    this.rewardedThisMonth = 0,
    this.isFirstFillUp = false,
    this.fillUpsThisMonth = 0,
  });
}

PointsAward pointsForFillUp(FillUpContext f) {
  if (!f.odometerConsistent) {
    return const PointsAward.none('Odometer is lower than last time');
  }
  if (f.rewardedToday >= maxRewardedFillUpsPerDay ||
      f.rewardedThisMonth >= maxRewardedFillUpsPerMonth) {
    return const PointsAward.none('Fill-up limit reached');
  }
  final reachesMonthlyGoal = f.fillUpsThisMonth + 1 == monthlyLoggingMinFillUps;
  return PointsAward([
    const PointsLine('Fill-up logged', fillUpBase),
    if (f.isComplete) const PointsLine('Complete details', fillUpCompleteBonus),
    if (reachesMonthlyGoal)
      const PointsLine(
        '$monthlyLoggingMinFillUps fill-ups this month',
        monthlyLoggingPoints,
      ),
    if (f.isFirstFillUp)
      PointsLine('First fill-up', Milestone.firstFillUp.points),
  ]);
}

/// Awarded once per calendar month for steady logging.
int monthlyLoggingBonus({required int fillUpsInMonth}) =>
    fillUpsInMonth >= monthlyLoggingMinFillUps ? monthlyLoggingPoints : 0;

/// Awarded once per month when km/L improved on last month's by 5%+.
int efficiencyBonus({
  required double previousKmPerLiter,
  required double kmPerLiter,
  required int tanks,
}) {
  if (tanks < efficiencyGainMinTanks || previousKmPerLiter <= 0) return 0;
  final gain = (kmPerLiter - previousKmPerLiter) / previousKmPerLiter;
  return gain >= efficiencyGainThreshold ? efficiencyGainPoints : 0;
}

PointsTier tierFor(int lifetimePoints) {
  var tier = PointsTier.bronze;
  for (final MapEntry(key: t, value: from) in tierThresholds.entries) {
    if (lifetimePoints >= from) tier = t;
  }
  return tier;
}

/// Points still needed for the next tier, or null at the top.
int? pointsToNextTier(int lifetimePoints) {
  for (final from in tierThresholds.values) {
    if (lifetimePoints < from) return from - lifetimePoints;
  }
  return null;
}
