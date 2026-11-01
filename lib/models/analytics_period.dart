import 'fuel_analytics.dart';

/// The stretch of time the Analytics headline sums up. Each range, except
/// all time, is compared with the stretch just before it.
enum AnalyticsRange {
  month('This month', 'vs last month', 1),
  quarter('3 months', 'vs the 3 before', 3),
  all('All time', null, null);

  final String label;

  /// Caption for the change against the previous stretch; null when there
  /// is nothing to compare with.
  final String? comparisonLabel;
  final int? months;

  const AnalyticsRange(this.label, this.comparisonLabel, this.months);
}

/// Spending, distance and efficiency over one stretch of time.
class PeriodSummary {
  final DateTime start;

  /// Exclusive.
  final DateTime end;
  final double spent;
  final int fillUps;

  /// Distance covered by tanks measured (refilled) in this stretch.
  final double km;
  final double? kmPerLiter;
  final double? costPerKm;

  const PeriodSummary({
    required this.start,
    required this.end,
    required this.spent,
    required this.fillUps,
    required this.km,
    this.kmPerLiter,
    this.costPerKm,
  });

  factory PeriodSummary.of(
    FuelAnalytics analytics,
    DateTime start,
    DateTime end,
  ) {
    bool inRange(DateTime d) => !d.isBefore(start) && d.isBefore(end);
    final fills = analytics.fillUps.where((f) => inRange(f.timestamp));
    final tanks = analytics.tanks.where((t) => inRange(t.measuredAt)).toList();
    final measured = tanks.where((t) => t.kmPerLiter != null);
    final measuredKm = measured.fold(0.0, (s, t) => s + t.km);
    final liters = measured.fold(0.0, (s, t) => s + t.liters!);
    final km = tanks.fold(0.0, (s, t) => s + t.km);
    final spentOverKm = tanks.fold(0.0, (s, t) => s + t.spent);
    return PeriodSummary(
      start: start,
      end: end,
      spent: fills.fold(0.0, (s, f) => s + f.amountSpent),
      fillUps: fills.length,
      km: km,
      kmPerLiter: liters > 0 ? measuredKm / liters : null,
      costPerKm: km > 0 ? spentOverKm / km : null,
    );
  }
}

/// A stretch of time next to the one before it, so the headline can say
/// "12% less than last month".
class PeriodComparison {
  final AnalyticsRange range;
  final PeriodSummary current;
  final PeriodSummary? previous;

  const PeriodComparison({
    required this.range,
    required this.current,
    this.previous,
  });

  /// Change in spending as a fraction (+0.12 = 12% more). Null without a
  /// previous stretch, or when nothing was spent then.
  double? get spentChange => _change(current.spent, previous?.spent);
  double? get kmChange => _change(current.km, previous?.km);
  double? get efficiencyChange =>
      _change(current.kmPerLiter, previous?.kmPerLiter);

  static double? _change(double? now, double? before) {
    if (now == null || before == null || before <= 0) return null;
    return (now - before) / before;
  }

  factory PeriodComparison.compute(
    FuelAnalytics analytics,
    AnalyticsRange range, {
    required DateTime now,
  }) {
    final months = range.months;
    if (months == null) {
      return PeriodComparison(
        range: range,
        current: PeriodSummary.of(analytics, DateTime(1970), DateTime(9999)),
      );
    }
    final end = DateTime(now.year, now.month + 1);
    final start = DateTime(now.year, now.month - months + 1);
    final previousStart = DateTime(now.year, now.month - 2 * months + 1);
    return PeriodComparison(
      range: range,
      current: PeriodSummary.of(analytics, start, end),
      previous: PeriodSummary.of(analytics, previousStart, start),
    );
  }
}
