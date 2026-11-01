import '../models/station_model.dart';
import '../services/current_location.dart';
import '../services/geo.dart';
import '../services/place_lookup.dart';

const _locationTimeout = Duration(seconds: 8);

/// A reported station this close counts as "the one you're at".
const reportedStationRadiusMeters = 150.0;

/// Where the user is as the fill-up form opens, and what's there.
class FillUpLocationGuess {
  final double latitude;
  final double longitude;

  /// A station from the app's own price reports, when one is right here.
  final StationModel? reportedStation;

  /// What OpenStreetMap knows about this spot (station brand / area).
  final PlaceGuess? place;

  const FillUpLocationGuess({
    required this.latitude,
    required this.longitude,
    this.reportedStation,
    this.place,
  });
}

/// The reported station within [reportedStationRadiusMeters] of the user.
StationModel? reportedStationAt(
  List<StationModel> stations,
  double lat,
  double lng,
) {
  StationModel? best;
  var bestDistance = reportedStationRadiusMeters;
  for (final s in stations) {
    if (s.latitude == 0 && s.longitude == 0) continue;
    final d = haversineMeters(lat, lng, s.latitude, s.longitude);
    if (d <= bestDistance) {
      best = s;
      bestDistance = d;
    }
  }
  return best;
}

/// Finds the user, then what station or area they're at. Null when the
/// location can't be read (off, denied, or no fix in time) — the form then
/// just works as before. It never prompts for permission from inside the
/// form; [locate] defaults to [readCurrentLocation].
///
/// [onFix] gets the coordinates as soon as GPS answers, before the
/// (slower, network) place lookup, so a quick save still keeps them.
Future<FillUpLocationGuess?> guessFillUpLocation({
  required List<StationModel> reportedStations,
  LocateOnce? locate,
  PlaceLookup? lookup,
  void Function(double latitude, double longitude)? onFix,
}) async {
  final fix =
      await (locate ?? () => readCurrentLocation(timeout: _locationTimeout))();
  if (fix == null) return null;
  final lat = fix.latitude;
  final lng = fix.longitude;
  onFix?.call(lat, lng);

  final reported = reportedStationAt(reportedStations, lat, lng);
  return FillUpLocationGuess(
    latitude: lat,
    longitude: lng,
    reportedStation: reported,
    place: reported == null
        ? await (lookup ?? PlaceLookup()).lookUp(lat, lng)
        : null,
  );
}
