import '../models/trip_point.dart';
import 'geo.dart';

const _startSpeedMps = 5.5; // ~20 km/h
const _startHold = Duration(seconds: 40);
const _startHoldWhenHinted = Duration(seconds: 15);
const _stopIdle = Duration(minutes: 5);
const _movingSpeedMps = 1.0;
const _maxAccuracyMeters = 30.0;
const _minStepMeters = 10.0;
const _maxPlausibleSpeedMps = 70.0; // ~250 km/h
const _meaningfulTripMeters = 500.0;

enum TrackerEvent { none, started, moved, ended }

class FinishedTrip {
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final List<TripPoint> points;

  const FinishedTrip({
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.points,
  });

  double get distanceKm => distanceMeters / 1000;

  /// Short hops (moving the car in a car park) are not worth recording.
  bool get isMeaningful => distanceMeters >= _meaningfulTripMeters;
}

class TrackerUpdate {
  final TrackerEvent event;
  final FinishedTrip? finishedTrip;

  const TrackerUpdate(this.event, {this.finishedTrip});

  static const none = TrackerUpdate(TrackerEvent.none);
}

/// Decides, from a stream of GPS samples, when a drive starts and ends, and
/// accumulates its distance. Pure logic: no platform or storage access.
///
/// A trip starts after ~40 s above ~20 km/h, and ends after 5 min without
/// movement. Noisy samples (poor accuracy, tiny steps, impossible jumps) are
/// ignored.
class TripTracker {
  TripPoint? _previous;
  final List<TripPoint> _candidate = [];
  final List<TripPoint> _points = [];
  double _distanceMeters = 0;
  bool _isTracking = false;
  DateTime? _lastMovingAt;

  /// Set when the phone itself senses a vehicle, so a trip can start sooner.
  /// Never starts a trip by itself: speed must still be sustained.
  bool drivingHint = false;

  bool get isTracking => _isTracking;
  double get distanceMeters => _distanceMeters;
  List<TripPoint> get points => List.unmodifiable(_points);
  DateTime? get startedAt => _points.isEmpty ? null : _points.first.timestamp;

  /// Begin a trip right now, from the user pressing "Track me".
  void startManual(TripPoint from) {
    _reset();
    _points.add(from);
    _previous = from;
    _lastMovingAt = from.timestamp;
    _isTracking = true;
  }

  /// End the trip at [at]. Returns null when no trip was in progress.
  FinishedTrip? stopManual(DateTime at) {
    if (!_isTracking) return null;
    return _finish(at);
  }

  TrackerUpdate onPoint(TripPoint p) {
    final accuracy = p.accuracyMeters;
    if (accuracy != null && accuracy > _maxAccuracyMeters) {
      return TrackerUpdate.none;
    }
    final speed = _speedOf(p);
    _previous = p;
    return _isTracking ? _whileTracking(p, speed) : _whileIdle(p, speed);
  }

  TrackerUpdate _whileIdle(TripPoint p, double speed) {
    if (speed < _startSpeedMps) {
      _candidate.clear();
      return TrackerUpdate.none;
    }
    _candidate.add(p);
    final held = p.timestamp.difference(_candidate.first.timestamp);
    if (held < (drivingHint ? _startHoldWhenHinted : _startHold)) {
      return TrackerUpdate.none;
    }

    _points
      ..clear()
      ..addAll(_candidate);
    _distanceMeters = _pathLength(_candidate);
    _lastMovingAt = p.timestamp;
    _isTracking = true;
    _candidate.clear();
    return const TrackerUpdate(TrackerEvent.started);
  }

  TrackerUpdate _whileTracking(TripPoint p, double speed) {
    if (speed >= _movingSpeedMps) _lastMovingAt = p.timestamp;

    final lastMoving = _lastMovingAt!;
    if (p.timestamp.difference(lastMoving) >= _stopIdle) {
      return TrackerUpdate(
        TrackerEvent.ended,
        finishedTrip: _finish(lastMoving),
      );
    }

    final last = _points.last;
    final step = _stepMeters(last, p);
    if (step < _minStepMeters) return TrackerUpdate.none;

    final seconds = p.timestamp.difference(last.timestamp).inMilliseconds / 1000;
    if (seconds > 0 && step / seconds > _maxPlausibleSpeedMps) {
      return TrackerUpdate.none;
    }

    _points.add(p);
    _distanceMeters += step;
    return const TrackerUpdate(TrackerEvent.moved);
  }

  /// Reported speed when the platform provides it, otherwise derived from the
  /// distance since the previous sample.
  double _speedOf(TripPoint p) {
    final reported = p.speedMps;
    if (reported != null && reported >= 0) return reported;
    final prev = _previous;
    if (prev == null) return 0;
    final seconds = p.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    final step = _stepMeters(prev, p);
    return step < _minStepMeters ? 0 : step / seconds;
  }

  double _stepMeters(TripPoint a, TripPoint b) =>
      haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);

  double _pathLength(List<TripPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _stepMeters(points[i - 1], points[i]);
    }
    return total;
  }

  FinishedTrip _finish(DateTime endedAt) {
    final trip = FinishedTrip(
      startedAt: _points.first.timestamp,
      endedAt: endedAt,
      distanceMeters: _distanceMeters,
      points: List.unmodifiable(_points),
    );
    _reset();
    return trip;
  }

  void _reset() {
    _candidate.clear();
    _points.clear();
    _distanceMeters = 0;
    _isTracking = false;
    _lastMovingAt = null;
  }
}

/// Rebuilds a trip from points saved before the app was killed mid-drive.
FinishedTrip? recoverTrip(List<TripPoint> points) {
  if (points.isEmpty) return null;
  var distance = 0.0;
  for (var i = 1; i < points.length; i++) {
    distance += haversineMeters(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
  }
  return FinishedTrip(
    startedAt: points.first.timestamp,
    endedAt: points.last.timestamp,
    distanceMeters: distance,
    points: List.unmodifiable(points),
  );
}
