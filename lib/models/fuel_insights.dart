import 'dart:math' as math;
import 'fill_up_model.dart';
import 'station_summary.dart';
import 'trip_model.dart';

/// What the user's fill-ups and recorded trips say about their driving costs.
class FuelInsights {
  final DateTime? lastFillAt;

  /// GPS-tracked km since the last fill-up.
  final double? kmSinceLastFill;

  /// Average distance between fill-ups, from odometer readings.
  final double? typicalRefillKm;
  final double? kmPerLiter;
  final double? costPerKm;

  /// Average liters per fill-up, for fills where liters were entered.
  final double? typicalLiters;

  const FuelInsights({
    this.lastFillAt,
    this.kmSinceLastFill,
    this.typicalRefillKm,
    this.kmPerLiter,
    this.costPerKm,
    this.typicalLiters,
  });

  double? get estimatedKmLeft {
    final typical = typicalRefillKm;
    final since = kmSinceLastFill;
    if (typical == null || since == null) return null;
    return math.max(0, typical - since);
  }

  /// 0 right after filling, 1 when the usual refill distance is reached.
  double? get tankUsedFraction {
    final typical = typicalRefillKm;
    final since = kmSinceLastFill;
    if (typical == null || typical <= 0 || since == null) return null;
    return (since / typical).clamp(0.0, 1.0);
  }

  factory FuelInsights.compute({
    required List<FillUp> fillUps,
    required List<Trip> trips,
  }) {
    if (fillUps.isEmpty) return const FuelInsights();

    final ordered = List<FillUp>.from(fillUps)
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        return byTime != 0 ? byTime : a.odometerKm.compareTo(b.odometerKm);
      });
    final last = ordered.last;

    final kmSince = trips
        .where((t) => t.startedAt.isAfter(last.timestamp))
        .fold(0.0, (sum, t) => sum + t.distanceKm);

    final gaps = <double>[];
    var litersWithGap = 0.0;
    var kmWithLiters = 0.0;
    for (var i = 0; i + 1 < ordered.length; i++) {
      final gap = ordered[i + 1].odometerKm - ordered[i].odometerKm;
      if (gap <= 0) continue;
      gaps.add(gap);
      final liters = ordered[i].liters;
      if (liters != null && liters > 0) {
        litersWithGap += liters;
        kmWithLiters += gap;
      }
    }

    final summaries = StationSummary.summarize(fillUps);
    final spent = summaries.fold(0.0, (s, x) => s + x.spentWithKnownKm);
    final km = summaries.fold(0.0, (s, x) => s + x.kmDriven);

    final litersEntered = fillUps
        .map((f) => f.liters)
        .whereType<double>()
        .where((l) => l > 0)
        .toList();

    return FuelInsights(
      lastFillAt: last.timestamp,
      kmSinceLastFill: kmSince,
      typicalRefillKm: gaps.isEmpty
          ? null
          : gaps.reduce((a, b) => a + b) / gaps.length,
      kmPerLiter: litersWithGap > 0 ? kmWithLiters / litersWithGap : null,
      costPerKm: km > 0 ? spent / km : null,
      typicalLiters: litersEntered.isEmpty
          ? null
          : litersEntered.reduce((a, b) => a + b) / litersEntered.length,
    );
  }
}

/// Whether driving to a cheaper station pays for itself.
class DetourVerdict {
  final double savings;
  final double detourCost;

  const DetourVerdict({required this.savings, required this.detourCost});

  double get net => savings - detourCost;
  bool get worthIt => net > 0;
}

DetourVerdict evaluateDetour({
  required double extraKm,
  required double costPerKm,
  required double priceHere,
  required double priceThere,
  required double liters,
}) {
  return DetourVerdict(
    savings: (priceHere - priceThere) * liters,
    detourCost: math.max(0, extraKm) * costPerKm,
  );
}
