import 'fill_up_model.dart';

/// A fill-up plus what it says about the driving since the one before it.
class FillUpLogEntry {
  final FillUp fillUp;

  /// Odometer distance since the previous fill-up; null for the first one.
  final double? kmSincePrevious;
  final double? kmPerLiter;
  final double? costPerKm;
  final bool isAboveAverage;

  const FillUpLogEntry({
    required this.fillUp,
    this.kmSincePrevious,
    this.kmPerLiter,
    this.costPerKm,
    this.isAboveAverage = false,
  });
}

/// The fill-up history as shown on the Tracker tab, newest first.
///
/// Efficiency uses the full-tank method: the km driven since the previous
/// fill-up were burned from the fuel bought now, so km/L = km ÷ liters now.
class FillUpLog {
  final List<FillUpLogEntry> entries;
  final double? averageKmPerLiter;

  const FillUpLog._(this.entries, this.averageKmPerLiter);

  factory FillUpLog.build(List<FillUp> fillUps) {
    final ordered = List<FillUp>.from(fillUps)
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        return byTime != 0 ? byTime : a.odometerKm.compareTo(b.odometerKm);
      });

    final raw = <FillUpLogEntry>[];
    for (var i = 0; i < ordered.length; i++) {
      final fill = ordered[i];
      final gap = i == 0 ? null : fill.odometerKm - ordered[i - 1].odometerKm;
      final km = gap != null && gap > 0 ? gap : null;
      final liters = fill.liters;
      raw.add(
        FillUpLogEntry(
          fillUp: fill,
          kmSincePrevious: km,
          kmPerLiter: km != null && liters != null && liters > 0
              ? km / liters
              : null,
          costPerKm: km != null ? fill.amountSpent / km : null,
        ),
      );
    }

    final efficiencies = [
      for (final e in raw)
        if (e.kmPerLiter != null) e.kmPerLiter!,
    ];
    final average = efficiencies.isEmpty
        ? null
        : efficiencies.reduce((a, b) => a + b) / efficiencies.length;

    final entries = [
      for (final e in raw.reversed)
        FillUpLogEntry(
          fillUp: e.fillUp,
          kmSincePrevious: e.kmSincePrevious,
          kmPerLiter: e.kmPerLiter,
          costPerKm: e.costPerKm,
          isAboveAverage:
              average != null &&
              efficiencies.length > 1 &&
              (e.kmPerLiter ?? 0) > average,
        ),
    ];
    return FillUpLog._(List.unmodifiable(entries), average);
  }
}
