import '../models/station_model.dart';
import '../models/trip_point.dart';
import 'geo.dart';

const _arriveRadiusMeters = 60.0;
const _leaveRadiusMeters =
    120.0; // wider than arrival so GPS wobble can't end a visit
const _dwell = Duration(minutes: 3);
const _cooldown = Duration(hours: 3);
const _maxAccuracyMeters = 50.0;
const _maxStoppedSpeedMps = 2.0; // ~7 km/h: queueing at the pump still counts

/// Notices when the user has stopped at a known gas station long enough that
/// they probably filled up. Pure logic: feed it GPS samples and clock ticks.
///
/// While idle the phone sends no samples when standing still, so a visit is
/// confirmed by time passing ([onTick]) as long as no sample shows the user
/// leaving.
class VisitDetector {
  List<StationModel> _stations = const [];
  final Map<String, DateTime> _lastNudged = {};
  TripPoint? _previous;
  StationModel? _candidate;
  DateTime? _arrivedAt;
  bool _confirmed = false;

  set stations(List<StationModel> value) {
    _stations = value
        .where((s) => s.latitude != 0 || s.longitude != 0)
        .toList();
  }

  /// True while the user is stopped at a station, i.e. ticks are needed.
  bool get isWatching => _candidate != null && !_confirmed;

  /// Returns the station when this sample confirms a visit.
  StationModel? onPoint(TripPoint p) {
    final accuracy = p.accuracyMeters;
    if (accuracy != null && accuracy > _maxAccuracyMeters) return null;
    final speed = _speedOf(p);
    _previous = p;

    final candidate = _candidate;
    if (candidate != null) {
      if (_distance(p, candidate) > _leaveRadiusMeters) {
        _clear();
      } else {
        return _check(p.timestamp);
      }
    }

    if (speed > _maxStoppedSpeedMps) return null;
    final nearest = _nearestWithin(p, _arriveRadiusMeters);
    if (nearest == null) return null;
    _candidate = nearest;
    _arrivedAt = p.timestamp;
    _confirmed = false;
    return null;
  }

  /// Returns the station when enough time has passed at it.
  StationModel? onTick(DateTime now) => _check(now);

  StationModel? _check(DateTime now) {
    final station = _candidate;
    final arrivedAt = _arrivedAt;
    if (station == null || arrivedAt == null || _confirmed) return null;
    if (now.difference(arrivedAt) < _dwell) return null;

    _confirmed = true;
    final last = _lastNudged[station.id];
    if (last != null && now.difference(last) < _cooldown) return null;
    _lastNudged[station.id] = now;
    return station;
  }

  StationModel? _nearestWithin(TripPoint p, double radius) {
    StationModel? best;
    var bestDistance = radius;
    for (final s in _stations) {
      final d = _distance(p, s);
      if (d <= bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  double _distance(TripPoint p, StationModel s) =>
      haversineMeters(p.latitude, p.longitude, s.latitude, s.longitude);

  double _speedOf(TripPoint p) {
    final reported = p.speedMps;
    if (reported != null && reported >= 0) return reported;
    final prev = _previous;
    if (prev == null) return 0;
    final seconds =
        p.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return haversineMeters(
          prev.latitude,
          prev.longitude,
          p.latitude,
          p.longitude,
        ) /
        seconds;
  }

  void _clear() {
    _candidate = null;
    _arrivedAt = null;
    _confirmed = false;
  }
}
