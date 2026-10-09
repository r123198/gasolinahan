import 'package:flutter/foundation.dart';
import '../models/fill_up_model.dart';
import '../models/station_summary.dart';
import '../services/fill_up_service.dart';

class FillUpViewModel extends ChangeNotifier {
  final FillUpService _service;

  FillUpViewModel({FillUpService? service})
      : _service = service ?? FillUpService();

  List<FillUp> _fillUps = const [];
  bool _isLoading = true;
  String? _errorMessage;

  List<FillUp> get fillUps => _fillUps;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<StationSummary> get summaries => StationSummary.summarize(_fillUps);
  TrackerTotals get totals => TrackerTotals.from(_fillUps);

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

  Future<void> remove(FillUp fillUp) async {
    final id = fillUp.id;
    if (id == null) return;
    try {
      await _service.delete(id);
      _fillUps = _fillUps.where((f) => f.id != id).toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Could not delete this fill-up.';
      if (kDebugMode) print('Fill-up delete error: $e');
    }
    notifyListeners();
  }
}
