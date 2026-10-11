import 'fill_up_model.dart';

/// A fill-up plus what it says about the driving since the one before it.
class FillUpLogEntry {
  final FillUp fillUp;

  /// Odometer distance since the previous fill-up; null for the first one.
  final double? kmSincePrevious;
  final double? kmPerLiter;
  final double? costPerKm;

  /// km/L beat the user's average (needs at least two efficiency readings).
  final bool isAboveAverage;

  /// ₱/km beat the user's average (needs at least two cost readings).
  final bool isCheaperPerKm;

  /// Price per liter minus the average of the user's other fill-ups of the
  /// same fuel; negative means this one was cheaper. Null when there is
  /// nothing to compare with.
  final double? priceDelta;

  const FillUpLogEntry({
    required this.fillUp,
    this.kmSincePrevious,
    this.kmPerLiter,
    this.costPerKm,
    this.isAboveAverage = false,
    this.isCheaperPerKm = false,
    this.priceDelta,
  });
}

/// Spending in one calendar month.
class MonthSummary {
  final double spent;
  final int fillUps;

  const MonthSummary({required this.spent, required this.fillUps});
}

/// The fill-up history as shown on the Tracker tab, newest first.
///
/// Efficiency uses the full-tank method: the km driven since the previous
/// fill-up were burned from the fuel bought now, so km/L = km ÷ liters now.
class FillUpLog {
  final List<FillUpLogEntry> entries;
  final double? averageKmPerLiter;
  final double? averageCostPerKm;

  const FillUpLog._(
    this.entries,
    this.averageKmPerLiter,
    this.averageCostPerKm,
  );

  /// Average price per liter across fill-ups that have one, or null.
  double? get averagePricePerLiter =>
      _average([for (final e in entries) ?e.fillUp.effectivePricePerLiter]);

  MonthSummary monthSummary(DateTime now) {
    final inMonth = entries.where(
      (e) =>
          e.fillUp.timestamp.year == now.year &&
          e.fillUp.timestamp.month == now.month,
    );
    return MonthSummary(
      spent: inMonth.fold(0.0, (sum, e) => sum + e.fillUp.amountSpent),
      fillUps: inMonth.length,
    );
  }

  factory FillUpLog.build(List<FillUp> fillUps) {
    final ordered = List<FillUp>.from(fillUps)
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        return byTime != 0 ? byTime : a.odometerKm.compareTo(b.odometerKm);
      });

    final kms = <double?>[];
    for (var i = 0; i < ordered.length; i++) {
      final gap = i == 0
          ? null
          : ordered[i].odometerKm - ordered[i - 1].odometerKm;
      kms.add(gap != null && gap > 0 ? gap : null);
    }
    final efficiencies = <double?>[
      for (var i = 0; i < ordered.length; i++)
        _kmPerLiter(kms[i], ordered[i].liters),
    ];
    final costs = <double?>[
      for (var i = 0; i < ordered.length; i++)
        kms[i] == null ? null : ordered[i].amountSpent / kms[i]!,
    ];
    final avgEfficiency = _average(efficiencies.nonNulls.toList());
    final avgCost = _average(costs.nonNulls.toList());
    final canCompareEfficiency = efficiencies.nonNulls.length > 1;
    final canCompareCost = costs.nonNulls.length > 1;

    final entries = [
      for (var i = ordered.length - 1; i >= 0; i--)
        FillUpLogEntry(
          fillUp: ordered[i],
          kmSincePrevious: kms[i],
          kmPerLiter: efficiencies[i],
          costPerKm: costs[i],
          isAboveAverage:
              canCompareEfficiency && (efficiencies[i] ?? 0) > avgEfficiency!,
          isCheaperPerKm:
              canCompareCost && costs[i] != null && costs[i]! < avgCost!,
          priceDelta: _priceDelta(ordered[i], ordered),
        ),
    ];
    return FillUpLog._(List.unmodifiable(entries), avgEfficiency, avgCost);
  }

  static double? _kmPerLiter(double? km, double? liters) =>
      km != null && liters != null && liters > 0 ? km / liters : null;

  static double? _priceDelta(FillUp fill, List<FillUp> all) {
    final price = fill.effectivePricePerLiter;
    if (price == null) return null;
    final others = _average([
      for (final f in all)
        if (!identical(f, fill) && f.fuelType == fill.fuelType)
          ?f.effectivePricePerLiter,
    ]);
    return others == null ? null : price - others;
  }

  static double? _average(List<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
}
