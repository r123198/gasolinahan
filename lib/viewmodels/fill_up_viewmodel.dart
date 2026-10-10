import 'package:flutter/foundation.dart';
import '../models/fill_up_log.dart';
import '../models/fill_up_model.dart';
import '../models/station_summary.dart';
import '../services/fill_up_photo_store.dart';
import '../services/fill_up_service.dart';

class FillUpViewModel extends ChangeNotifier {
  final FillUpService _service;
  final FillUpPhotoStore _photos;

  FillUpViewModel({FillUpService? service, FillUpPhotoStore? photos})
    : _service = service ?? FillUpService(),
      _photos = photos ?? FillUpPhotoStore();

  List<FillUp> _fillUps = const [];
  bool _isLoading = true;
  String? _errorMessage;

  List<FillUp> get fillUps => _fillUps;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<StationSummary> get summaries => StationSummary.summarize(_fillUps);
  TrackerTotals get totals => TrackerTotals.from(_fillUps);
  FillUpLog get log => FillUpLog.build(_fillUps);

  /// The most recent fill-up, used to pre-fill the next one.
  FillUp? get latest => _fillUps.isEmpty
      ? null
      : _fillUps.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

  /// Last price paid for [fuelType] at [stationId], if any.
  double? lastPriceAt(String stationId, String fuelType) {
    final matches =
        _fillUps
            .where(
              (f) =>
                  f.stationId == stationId &&
                  f.fuelType == fuelType &&
                  f.effectivePricePerLiter != null,
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.isEmpty ? null : matches.first.effectivePricePerLiter;
  }

  /// Highest odometer reading logged so far, used to sanity-check new entries.
  double? get lastOdometer => _fillUps.isEmpty
      ? null
      : _fillUps.map((f) => f.odometerKm).reduce((a, b) => a > b ? a : b);

  List<FillUp> historyFor(String key) =>
      StationSummary.historyFor(key, _fillUps);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _fillUps = await _service.getAll();
    } catch (e) {
      _errorMessage = 'Could not load your fill-ups.';
      if (kDebugMode) print('Fill-up load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when the fill-up was saved.
  Future<bool> add(FillUp fillUp) async {
    try {
      await _service.insert(fillUp);
      _fillUps = await _service.getAll();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not save this fill-up.';
      if (kDebugMode) print('Fill-up save error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Saves edits to an existing fill-up. Returns true when saved.
  Future<bool> update(
    FillUp fillUp, {
    Iterable<String> removedPhotos = const [],
  }) async {
    try {
      await _service.update(fillUp);
      _fillUps = await _service.getAll();
      _errorMessage = null;
      notifyListeners();
      await _photos.discard(removedPhotos);
      return true;
    } catch (e) {
      _errorMessage = 'Could not save your changes.';
      if (kDebugMode) print('Fill-up update error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> remove(FillUp fillUp) async {
    final id = fillUp.id;
    if (id == null) return;
    try {
      await _service.delete(id);
      _fillUps = _fillUps.where((f) => f.id != id).toList();
      _errorMessage = null;
      await _photos.discard(fillUp.photoPaths);
    } catch (e) {
      _errorMessage = 'Could not delete this fill-up.';
      if (kDebugMode) print('Fill-up delete error: $e');
    }
    notifyListeners();
  }
}
