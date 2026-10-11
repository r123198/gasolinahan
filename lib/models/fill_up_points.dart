import 'fill_up_model.dart';
import 'points_rules.dart';

/// The facts [pointsForFillUp] needs about [newFill], read from the user's
/// existing log ([history] must not include [newFill]).
FillUpContext fillUpPointsContext({
  required FillUp newFill,
  required List<FillUp> history,
}) {
  final at = newFill.timestamp;
  bool sameMonth(FillUp f) =>
      f.timestamp.year == at.year && f.timestamp.month == at.month;
  bool sameDay(FillUp f) => sameMonth(f) && f.timestamp.day == at.day;

  final before = history.where((f) => !f.timestamp.isAfter(at));
  final previous = before.isEmpty
      ? null
      : before.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

  return FillUpContext(
    isComplete: (newFill.pricePerLiter ?? 0) > 0 && newFill.productName != null,
    odometerConsistent:
        previous == null || newFill.odometerKm > previous.odometerKm,
    rewardedToday: history
        .where((f) => f.pointsAwarded > 0 && sameDay(f))
        .length,
    rewardedThisMonth: history
        .where((f) => f.pointsAwarded > 0 && sameMonth(f))
        .length,
    fillUpsThisMonth: history.where(sameMonth).length,
    isFirstFillUp: history.isEmpty,
  );
}
