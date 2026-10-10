import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fill_up_model.dart';
import '../models/station_model.dart';
import '../models/trip_point.dart';
import '../services/nudge_notifier.dart';
import '../services/visit_detector.dart';

const _recentFillUp = Duration(hours: 3);
const _defaultTick = Duration(seconds: 30);

/// Turns "stopped at a gas station for a few minutes" into a "Did you fill
/// up?" notification, and a tap on it into an opened fill-up form.
class FillUpNudgeViewModel extends ChangeNotifier {
  final NudgeNotifier _notifier;
  final VisitDetector _detector;
  final DateTime Function() _clock;
  final Duration _tickEvery;

  FillUpNudgeViewModel({
    NudgeNotifier? notifier,
    VisitDetector? detector,
    DateTime Function()? clock,
    Duration tickEvery = _defaultTick,
  }) : _notifier = notifier ?? DeviceNudgeNotifier(),
       _detector = detector ?? VisitDetector(),
       _clock = clock ?? DateTime.now,
       _tickEvery = tickEvery;

  List<StationModel> _stations = const [];
  List<FillUp> _fillUps = const [];
  String? _pendingStationId;
  StreamSubscription<TripPoint>? _subscription;
  Timer? _ticker;
  bool _isStarted = false;

  void updateStations(List<StationModel> stations) {
    _stations = stations;
    _detector.stations = stations;
    if (_pendingStationId != null && _findStation(_pendingStationId!) != null) {
      notifyListeners();
    }
  }

  void updateFillUps(List<FillUp> fillUps) => _fillUps = fillUps;

  Future<void> start(Stream<TripPoint> locationUpdates) async {
    if (_isStarted) return;
    _isStarted = true;
    try {
      await _notifier.init(onTap: _onTap);
      final launchedFrom = await _notifier.launchStationId();
      if (launchedFrom != null) _pendingStationId = launchedFrom;
    } catch (e) {
      // Without notifications the rest of the app still works.
      if (kDebugMode) print('Notifications unavailable: $e');
    }
    _subscription = locationUpdates.listen((p) {
      final station = _detector.onPoint(p);
      if (station != null) unawaited(_nudge(station));
    });
    _ticker = Timer.periodic(_tickEvery, (_) => tick());
  }

  /// Checks whether the user has now been at a station long enough. Driven
  /// by a timer because the phone sends no GPS samples while standing still.
  Future<void> tick() async {
    if (!_detector.isWatching) return;
    final station = _detector.onTick(_clock());
    if (station != null) await _nudge(station);
  }

  /// The station to open the fill-up form for, once. Null when none.
  StationModel? takePendingStation() {
    final id = _pendingStationId;
    if (id == null) return null;
    final station = _findStation(id);
    if (station == null) return null; // stations may still be loading
    _pendingStationId = null;
    return station;
  }

  Future<void> _nudge(StationModel station) async {
    if (_loggedRecently(station)) return;
    try {
      await _notifier.showFillUpNudge(station);
    } catch (e) {
      if (kDebugMode) print('Could not show fill-up nudge: $e');
    }
  }

  bool _loggedRecently(StationModel station) {
    final now = _clock();
    return _fillUps.any(
      (f) =>
          f.stationId == station.id &&
          now.difference(f.timestamp).abs() < _recentFillUp,
    );
  }

  void _onTap(String stationId) {
    _pendingStationId = stationId;
    notifyListeners();
  }

  StationModel? _findStation(String id) =>
      _stations.where((s) => s.id == id).firstOrNull;

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
