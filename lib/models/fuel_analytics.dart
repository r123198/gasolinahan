import 'brand_registry.dart';
import 'fill_up_model.dart';

/// A brand needs this many measured tanks before it can be called the best.
const minTanksForBestBrand = 2;
const monthsOfSpend = 6;
const _daysPerMonth = 30;

/// Within this of the average, a tank counts as "your usual".
const _usualEfficiencyBand = 0.05;

/// How the latest tank compares with the user's own average km/L.
enum EfficiencyVerdict { efficient, usual, wasteful }

/// How one fuel brand performed in the user's own car.
class BrandPerformance {
  final String brand;

  /// Tanks of this brand whose efficiency could be measured.
  final int tanks;
  final double kmPerLiter;
  final double costPerKm;
  final double? averagePricePerLiter;

  const BrandPerformance({
    required this.brand,
    required this.tanks,
    required this.kmPerLiter,
    required this.costPerKm,
    this.averagePricePerLiter,
  });
}

/// One tank: the fill-up that filled it and how far that fuel went.
class TankRecord {
  final FillUp filledAt;
  final DateTime measuredAt;
  final double km;
  final int days;
  final double? kmPerLiter;

  /// What the refill at [measuredAt] cost: the price of driving [km].
  final double spent;

  const TankRecord({
    required this.filledAt,
    required this.measuredAt,
    required this.km,
    required this.days,
    required this.spent,
    this.kmPerLiter,
  });

  /// Liters this tank burned, when its efficiency is known.
  double? get liters => kmPerLiter == null ? null : km / kmPerLiter!;
}

class PriceRecord {
  final FillUp fillUp;
  final double pricePerLiter;

  const PriceRecord(this.fillUp, this.pricePerLiter);
}

class TrendPoint {
  final DateTime date;
  final double value;

  const TrendPoint(this.date, this.value);
}

/// One calendar month: what was spent, how far was driven (tanks measured
/// that month) and how many fill-ups there were.
class MonthSpend {
  final DateTime month;
  final double spent;
  final double km;
  final int fillUps;

  const MonthSpend(this.month, this.spent, {this.km = 0, this.fillUps = 0});
}

/// Everything the Analytics screen shows, worked out from the fill-up log.
///
/// Uses the full-tank method: the liters bought at a fill-up replace the
/// fuel burned since the previous one, so each tank's km/L belongs to the
/// fill-up (and brand) *before* it.
class FuelAnalytics {
  /// Every fill-up, oldest first.
  final List<FillUp> fillUps;
  final List<TankRecord> tanks;
  final List<BrandPerformance> brands;
  final List<TrendPoint> efficiencyTrend;
  final List<TrendPoint> priceTrend;
  final List<MonthSpend> monthlySpend;
  final double? averageKmPerLiter;
  final double? averageCostPerKm;
  final double? averagePricePerLiter;
  final double? kmPerDay;
  final PriceRecord? cheapestPrice;
  final PriceRecord? priciestPrice;

  const FuelAnalytics._({
    required this.fillUps,
    required this.tanks,
    required this.brands,
    required this.efficiencyTrend,
    required this.priceTrend,
    required this.monthlySpend,
    this.averageKmPerLiter,
    this.averageCostPerKm,
    this.averagePricePerLiter,
    this.kmPerDay,
    this.cheapestPrice,
    this.priciestPrice,
  });

  /// Two fill-ups make the first measured tank.
  bool get hasEnoughData => tanks.isNotEmpty;

  /// Top brand by km/L, once it has enough tanks to trust.
  BrandPerformance? get bestBrand {
    final ranked = brands.where((b) => b.tanks >= minTanksForBestBrand);
    return ranked.isEmpty ? null : ranked.first;
  }

  /// How much further the best brand goes per liter than the runner-up
  /// (0.25 = 25% more km per liter). Null without a runner-up.
  double? get bestBrandAdvantage {
    final best = bestBrand;
    if (best == null) return null;
    final rest = brands.where((b) => b != best && b.tanks >= 1);
    if (rest.isEmpty) return null;
    final runnerUp = rest.first;
    return (best.kmPerLiter - runnerUp.kmPerLiter) / runnerUp.kmPerLiter;
  }

  TankRecord? get longestGap => _maxBy(tanks, (t) => t.days.toDouble());

  TankRecord? get bestTank =>
      _maxBy(tanks.where((t) => t.kmPerLiter != null), (t) => t.kmPerLiter!);

  TankRecord? get worstTank =>
      _maxBy(tanks.where((t) => t.kmPerLiter != null), (t) => -t.kmPerLiter!);

  /// The most recent tank with a known km/L.
  TankRecord? get latestTank =>
      tanks.where((t) => t.kmPerLiter != null).lastOrNull;

  /// The latest tank's km/L against the average, as a fraction (+0.08 =
  /// 8% further per liter than usual). Null until two tanks are measured.
  double? get latestEfficiencyChange {
    final latest = latestTank?.kmPerLiter;
    final average = averageKmPerLiter;
    final measured = tanks.where((t) => t.kmPerLiter != null).length;
    if (latest == null || average == null || average <= 0 || measured < 2) {
      return null;
    }
    return (latest - average) / average;
  }

  /// "How wasteful am I lately": the latest tank, judged against the
  /// user's own average.
  EfficiencyVerdict? get verdict {
    final change = latestEfficiencyChange;
    if (change == null) return null;
    if (change >= _usualEfficiencyBand) return EfficiencyVerdict.efficient;
    if (change <= -_usualEfficiencyBand) return EfficiencyVerdict.wasteful;
    return EfficiencyVerdict.usual;
  }

  double? get averageDaysBetween =>
      _average(tanks.map((t) => t.days.toDouble()));

  double? get averageKmBetween => _average(tanks.map((t) => t.km));

  /// Fuel cost for a month of driving at the current pace and ₱/km.
  double? get projectedMonthlyCost {
    final pace = kmPerDay;
    final cost = averageCostPerKm;
    if (pace == null || cost == null) return null;
    return pace * _daysPerMonth * cost;
  }

  factory FuelAnalytics.compute(List<FillUp> fillUps, {required DateTime now}) {
    final ordered = List<FillUp>.from(fillUps)
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        return byTime != 0 ? byTime : a.odometerKm.compareTo(b.odometerKm);
      });

    final tanks = <TankRecord>[];
    var spentOnMeasuredKm = 0.0;
    for (var i = 1; i < ordered.length; i++) {
      final prev = ordered[i - 1];
      final next = ordered[i];
      final km = next.odometerKm - prev.odometerKm;
      if (km <= 0) continue;
      final liters = next.liters;
      tanks.add(
        TankRecord(
          filledAt: prev,
          measuredAt: next.timestamp,
          km: km,
          days: next.timestamp.difference(prev.timestamp).inDays,
          spent: next.amountSpent,
          kmPerLiter: liters != null && liters > 0 ? km / liters : null,
        ),
      );
      spentOnMeasuredKm += next.amountSpent;
    }

    final totalKm = tanks.fold(0.0, (s, t) => s + t.km);
    final prices = [
      for (final f in ordered)
        if (f.effectivePricePerLiter case final p?) PriceRecord(f, p),
    ];
    // Only the days the measured km were driven over: a gap skipped for an
    // odometer typo or reset mustn't dilute the pace.
    final span = tanks.fold(0, (s, t) => s + t.days);

    return FuelAnalytics._(
      fillUps: List.unmodifiable(ordered),
      tanks: List.unmodifiable(tanks),
      brands: _brandPerformance(tanks, ordered),
      efficiencyTrend: [
        for (final t in tanks)
          if (t.kmPerLiter case final v?) TrendPoint(t.measuredAt, v),
      ],
      priceTrend: [
        for (final p in prices) TrendPoint(p.fillUp.timestamp, p.pricePerLiter),
      ],
      monthlySpend: _monthly(ordered, tanks, now),
      averageKmPerLiter: _average([for (final t in tanks) ?t.kmPerLiter]),
      averageCostPerKm: totalKm > 0 ? spentOnMeasuredKm / totalKm : null,
      averagePricePerLiter: _average(prices.map((p) => p.pricePerLiter)),
      kmPerDay: span > 0 && totalKm > 0 ? totalKm / span : null,
      cheapestPrice: _maxBy(prices, (p) => -p.pricePerLiter),
      priciestPrice: _maxBy(prices, (p) => p.pricePerLiter),
    );
  }

  static String brandOf(FillUp f) =>
      BrandRegistry.match(f.brand, stationName: f.stationName)?.name ??
      (f.brand.trim().isEmpty ? 'Other' : f.brand.trim());

  static List<BrandPerformance> _brandPerformance(
    List<TankRecord> tanks,
    List<FillUp> ordered,
  ) {
    final byBrand = <String, List<TankRecord>>{};
    for (final t in tanks.where((t) => t.kmPerLiter != null)) {
      byBrand.putIfAbsent(brandOf(t.filledAt), () => []).add(t);
    }
    final result = [
      for (final MapEntry(key: brand, value: list) in byBrand.entries)
        BrandPerformance(
          brand: brand,
          tanks: list.length,
          // Pooled (total km ÷ total liters) so long tanks count for more.
          kmPerLiter:
              list.fold(0.0, (s, t) => s + t.km) /
              list.fold(0.0, (s, t) => s + t.km / t.kmPerLiter!),
          costPerKm:
              list.fold(0.0, (s, t) => s + _costOf(t, ordered)) /
              list.fold(0.0, (s, t) => s + t.km),
          averagePricePerLiter: _average([
            for (final t in list) ?t.filledAt.effectivePricePerLiter,
          ]),
        ),
    ]..sort((a, b) => b.kmPerLiter.compareTo(a.kmPerLiter));
    return List.unmodifiable(result);
  }

  /// What the fuel for [tank] cost: the liters burned at this brand's price,
  /// falling back to what was paid to refill it.
  static double _costOf(TankRecord tank, List<FillUp> ordered) {
    final price = tank.filledAt.effectivePricePerLiter;
    final kmPerLiter = tank.kmPerLiter;
    if (price != null && kmPerLiter != null) {
      return tank.km / kmPerLiter * price;
    }
    final refill = ordered.firstWhere(
      (f) => f.timestamp == tank.measuredAt,
      orElse: () => tank.filledAt,
    );
    return refill.amountSpent;
  }

  static List<MonthSpend> _monthly(
    List<FillUp> fills,
    List<TankRecord> tanks,
    DateTime now,
  ) {
    bool inMonth(DateTime d, DateTime month) =>
        d.year == month.year && d.month == month.month;
    return List.unmodifiable([
      for (var back = monthsOfSpend - 1; back >= 0; back--)
        () {
          final month = DateTime(now.year, now.month - back);
          final inThis = fills.where((f) => inMonth(f.timestamp, month));
          return MonthSpend(
            month,
            inThis.fold(0.0, (s, f) => s + f.amountSpent),
            km: tanks
                .where((t) => inMonth(t.measuredAt, month))
                .fold(0.0, (s, t) => s + t.km),
            fillUps: inThis.length,
          );
        }(),
    ]);
  }

  static double? _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;
  }

  static T? _maxBy<T>(Iterable<T> items, double Function(T) key) {
    T? best;
    for (final item in items) {
      if (best == null || key(item) > key(best)) best = item;
    }
    return best;
  }
}
