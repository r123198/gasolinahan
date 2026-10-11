import 'fill_up_model.dart';

/// Per-station roll-up of the user's fill-ups.
class StationSummary {
  final String key;
  final String stationId;
  final String stationName;
  final String brand;
  final int visits;
  final double totalSpent;

  /// Km driven on tanks filled here (odometer at the next fill-up, from any
  /// station, minus the odometer at this one). The latest fill-up overall has
  /// no next fill-up yet and so contributes nothing.
  final double kmDriven;

  /// Amount spent on the fill-ups that have a known km, so cost per km
  /// compares like with like.
  final double spentWithKnownKm;
  final double totalLiters;
  final FillUp lastFillUp;

  const StationSummary({
    required this.key,
    required this.stationId,
    required this.stationName,
    required this.brand,
    required this.visits,
    required this.totalSpent,
    required this.kmDriven,
    required this.spentWithKnownKm,
    required this.totalLiters,
    required this.lastFillUp,
  });

  double? get costPerKm => kmDriven > 0 ? spentWithKnownKm / kmDriven : null;

  /// Station summaries, most recently visited first.
  static List<StationSummary> summarize(List<FillUp> fillUps) {
    final ordered = _chronological(fillUps);
    final groups = <String, List<_Entry>>{};
    for (var i = 0; i < ordered.length; i++) {
      final fill = ordered[i];
      final next = i + 1 < ordered.length ? ordered[i + 1] : null;
      final km = next == null ? 0.0 : next.odometerKm - fill.odometerKm;
      groups
          .putIfAbsent(keyOf(fill), () => [])
          .add(_Entry(fill, km > 0 ? km : 0));
    }

    final summaries = groups.entries.map((e) {
      final entries = e.value;
      final last = entries.last.fill;
      return StationSummary(
        key: e.key,
        stationId: last.stationId,
        stationName: last.stationName,
        brand: last.brand,
        visits: entries.length,
        totalSpent: entries.fold(0.0, (s, x) => s + x.fill.amountSpent),
        kmDriven: entries.fold(0.0, (s, x) => s + x.km),
        spentWithKnownKm: entries
            .where((x) => x.km > 0)
            .fold(0.0, (s, x) => s + x.fill.amountSpent),
        totalLiters: entries.fold(0.0, (s, x) => s + (x.fill.liters ?? 0)),
        lastFillUp: last,
      );
    }).toList();

    summaries.sort(
      (a, b) => b.lastFillUp.timestamp.compareTo(a.lastFillUp.timestamp),
    );
    return summaries;
  }

  /// Fill-ups for one summary, newest first.
  static List<FillUp> historyFor(String key, List<FillUp> fillUps) {
    return _chronological(
      fillUps.where((f) => keyOf(f) == key).toList(),
    ).reversed.toList();
  }

  static String keyOf(FillUp f) =>
      f.stationId.isNotEmpty ? f.stationId : f.stationName.toLowerCase();

  static List<FillUp> _chronological(List<FillUp> fillUps) {
    final sorted = List<FillUp>.from(fillUps);
    sorted.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      return byTime != 0 ? byTime : a.odometerKm.compareTo(b.odometerKm);
    });
    return sorted;
  }
}

class _Entry {
  final FillUp fill;
  final double km;
  const _Entry(this.fill, this.km);
}

/// Totals across every station.
class TrackerTotals {
  final int fillUps;
  final double totalSpent;
  final double totalKm;

  /// Spend on the fuel burned over [totalKm]: everything except the first
  /// fill-up, whose fuel no logged distance covers yet.
  final double spentOverKm;

  const TrackerTotals({
    required this.fillUps,
    required this.totalSpent,
    required this.totalKm,
    this.spentOverKm = 0,
  });

  double? get costPerKm => totalKm > 0 ? spentOverKm / totalKm : null;

  factory TrackerTotals.from(List<FillUp> fillUps) {
    if (fillUps.isEmpty) {
      return const TrackerTotals(fillUps: 0, totalSpent: 0, totalKm: 0);
    }
    final first = fillUps.reduce(
      (a, b) => a.odometerKm <= b.odometerKm ? a : b,
    );
    final highest = fillUps
        .map((f) => f.odometerKm)
        .reduce((a, b) => a > b ? a : b);
    final totalSpent = fillUps.fold(0.0, (s, f) => s + f.amountSpent);
    return TrackerTotals(
      fillUps: fillUps.length,
      totalSpent: totalSpent,
      totalKm: highest - first.odometerKm,
      spentOverKm: totalSpent - first.amountSpent,
    );
  }
}
