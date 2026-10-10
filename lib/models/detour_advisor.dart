import '../services/geo.dart';
import 'fuel_insights.dart';
import 'station_model.dart';

/// Straight-line distance understates road distance; this is a typical
/// city factor.
const _roadFactor = 1.3;

class DetourAdvice {
  /// The station you would likely stop at anyway: the closest one.
  final StationModel nearest;
  final double priceHere;
  final double priceThere;
  final double extraKm;
  final DetourVerdict verdict;

  /// True when the target is itself the closest station, so there is no detour.
  final bool isClosest;

  const DetourAdvice({
    required this.nearest,
    required this.priceHere,
    required this.priceThere,
    required this.extraKm,
    required this.verdict,
    required this.isClosest,
  });
}

/// Is driving to [target] instead of the closest priced station worth it?
/// Returns null when there is nothing sensible to compare.
DetourAdvice? adviseDetour({
  required double userLat,
  required double userLng,
  required StationModel target,
  required List<StationModel> stations,
  required double Function(StationModel) priceOf,
  required double costPerKm,
  required double liters,
}) {
  final priceThere = priceOf(target);
  if (priceThere <= 0) return null;

  double distanceTo(StationModel s) =>
      haversineMeters(userLat, userLng, s.latitude, s.longitude);

  final others =
      stations
          .where(
            (s) =>
                s.id != target.id &&
                priceOf(s) > 0 &&
                (s.latitude != 0 || s.longitude != 0),
          )
          .toList()
        ..sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));
  if (others.isEmpty) return null;

  final closestOther = others.first;
  final extraMeters = distanceTo(target) - distanceTo(closestOther);
  if (extraMeters <= 0) {
    return DetourAdvice(
      nearest: target,
      priceHere: priceThere,
      priceThere: priceThere,
      extraKm: 0,
      verdict: const DetourVerdict(savings: 0, detourCost: 0),
      isClosest: true,
    );
  }

  final extraKm = extraMeters / 1000 * _roadFactor * 2; // there and back
  final priceHere = priceOf(closestOther);
  return DetourAdvice(
    nearest: closestOther,
    priceHere: priceHere,
    priceThere: priceThere,
    extraKm: extraKm,
    verdict: evaluateDetour(
      extraKm: extraKm,
      costPerKm: costPerKm,
      priceHere: priceHere,
      priceThere: priceThere,
      liters: liters,
    ),
    isClosest: false,
  );
}
