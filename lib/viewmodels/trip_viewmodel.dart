import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/trip_model.dart';
import '../models/trip_point.dart';
import '../services/driving_activity_source.dart';
import '../services/location_source.dart';
import '../services/trip_service.dart';
import '../services/trip_tracker.dart';

/// Watches location, records drives automatically, and exposes the live route.
class TripViewModel extends ChangeNotifier {
  final TripTracker _tracker;
  final TripService _service;
  final LocationSource _source;
  final DrivingActivitySource _activity;

  TripViewModel({
    TripTracker? tracker,
    TripService? service,
    LocationSource? source,
    DrivingActivitySource? activity,
  }) : _tracker = tracker ?? TripTracker(),
       _service = service ?? TripService(),
       _source = source ?? DeviceLocationSource(),
       _activity = activity ?? DeviceDrivingActivitySource();

  StreamSubscription<TripPoint>? _subscription;
  final StreamController<TripPoint> _locationUpdates =
      StreamController<TripPoint>.broadcast();
  StreamSubscription<bool>? _activitySubscription;
  TripPoint? _lastPoint;
  int? _activeTripId;
  bool _manualPending = false;
  bool _isMonitoring = false;
  bool _permissionDenied = false;
  List<Trip> _history = const [];
  String? _errorMessage;

  bool get isMonitoring => _isMonitoring;
  bool get permissionDenied => _permissionDenied;
  bool get isTracking => _tracker.isTracking || _manualPending;
  double get liveDistanceKm => _tracker.distanceMeters / 1000;
  List<TripPoint> get livePoints => _tracker.points;
  List<Trip> get history => _history;

  /// Every GPS sample received, for other features (fill-up nudges) that need
  /// location without starting a second location stream.
  Stream<TripPoint> get locationUpdates => _locationUpdates.stream;
  String? get errorMessage => _errorMessage;

  /// Starts watching for drives. Safe to call more than once.
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    final allowed = await _source.start();
    _permissionDenied = !allowed;
    if (!allowed) {
      notifyListeners();
      return;
    }
    _isMonitoring = true;
    await _recoverInterruptedTrips();
    _subscription = _source.points.listen(
      _onPoint,
      onError: (Object e) {
        _errorMessage = 'Location is unavailable right now.';
        if (kDebugMode) print('Location stream error: $e');
        notifyListeners();
      },
    );
    await _listenForVehicle();
    await loadHistory();
  }

  /// "Track me": start a trip now rather than waiting for driving speed.
  Future<void> trackNow() async {
    if (isTracking) return;
    await startMonitoring();
    if (!_isMonitoring) return;
    final last = _lastPoint;
    if (last == null) {
      _manualPending = true; // starts on the next GPS sample
    } else {
      await _beginManual(last);
    }
    notifyListeners();
  }

  Future<void> stopNow() async {
    _manualPending = false;
    final trip = _tracker.stopManual(DateTime.now());
    await _source.setPrecise(false);
    if (trip != null) await _finishActive(trip);
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      _history = await _service.getAll();
    } catch (e) {
      _errorMessage = 'Could not load your trips.';
      if (kDebugMode) print('Trip history error: $e');
    }
    notifyListeners();
  }

  Future<void> deleteTrip(Trip trip) async {
    final id = trip.id;
    if (id == null) return;
    try {
      await _service.delete(id);
      _history = _history.where((t) => t.id != id).toList();
    } catch (e) {
      _errorMessage = 'Could not delete this trip.';
      if (kDebugMode) print('Trip delete error: $e');
    }
    notifyListeners();
  }

  Future<List<TripPoint>> routeFor(Trip trip) {
    final id = trip.id;
    return id == null ? Future.value(const []) : _service.pointsFor(id);
  }

  Future<void> _onPoint(TripPoint p) async {
    _lastPoint = p;
    _locationUpdates.add(p);
    if (_manualPending) {
      _manualPending = false;
      await _beginManual(p);
      notifyListeners();
      return;
    }

    final update = _tracker.onPoint(p);
    switch (update.event) {
      case TrackerEvent.started:
        await _source.setPrecise(true);
        await _persist(() async {
          _activeTripId = await _service.beginActive(
            _tracker.startedAt ?? p.timestamp,
            _tracker.points,
          );
        });
        notifyListeners();
      case TrackerEvent.moved:
        final id = _activeTripId;
        if (id != null) await _persist(() => _service.appendPoint(id, p));
        notifyListeners();
      case TrackerEvent.ended:
        await _source.setPrecise(false);
        final trip = update.finishedTrip;
        if (trip != null) await _finishActive(trip);
        notifyListeners();
      case TrackerEvent.none:
        break;
    }
  }

  /// Uses the phone's own driving sense as a hint: sample GPS closely and let
  /// a trip start sooner. Optional, so any failure is ignored.
  Future<void> _listenForVehicle() async {
    try {
      if (!await _activity.start()) return;
      _activitySubscription = _activity.inVehicle.listen(
        _onVehicleSignal,
        onError: (Object e) {
          if (kDebugMode) print('Activity stream error: $e');
        },
      );
    } catch (e) {
      if (kDebugMode) print('Activity recognition unavailable: $e');
    }
  }

  Future<void> _onVehicleSignal(bool inVehicle) async {
    _tracker.drivingHint = inVehicle;
    if (!_tracker.isTracking) await _source.setPrecise(inVehicle);
  }

  Future<void> _beginManual(TripPoint from) async {
    _tracker.startManual(from);
    await _source.setPrecise(true);
    await _persist(() async {
      _activeTripId = await _service.beginActive(from.timestamp, [from]);
    });
  }

  /// Completes the trip being recorded: keeps it, or drops it when too short.
  Future<void> _finishActive(FinishedTrip trip) async {
    final id = _activeTripId;
    _activeTripId = null;
    if (id == null) return;
    await _persist(() async {
      if (trip.isMeaningful) {
        await _service.finalize(id, trip);
      } else {
        await _service.delete(id);
      }
      _history = await _service.getAll();
    });
  }

  /// Finishes any trip left active by a previous run that was killed.
  Future<void> _recoverInterruptedTrips() async {
    await _persist(() async {
      for (final id in await _service.activeTripIds()) {
        final trip = recoverTrip(await _service.pointsFor(id));
        if (trip != null && trip.isMeaningful) {
          await _service.finalize(id, trip);
        } else {
          await _service.delete(id);
        }
      }
    });
  }

  /// Storage failures must never interrupt a drive that is being recorded.
  Future<void> _persist(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _errorMessage = 'Could not save this trip.';
      if (kDebugMode) print('Trip storage error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _activitySubscription?.cancel();
    _locationUpdates.close();
    super.dispose();
  }
}
