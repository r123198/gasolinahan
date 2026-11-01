import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/station_model.dart';
import '../services/firebase_service.dart';

enum FuelType { regular, premium, diesel }

class DashboardViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<StationModel> _nearbyStations = [];
  bool _isLoading = true;
  FuelType _fuelType = FuelType.regular;
  bool _onlyWithPrices = false;
  String? _errorMessage;
  StreamSubscription? _stationsSubscription;

  List<StationModel> get nearbyStations => _nearbyStations;
  bool get isLoading => _isLoading;
  FuelType get fuelType => _fuelType;
  bool get onlyWithPrices => _onlyWithPrices;
  String? get errorMessage => _errorMessage;

  List<StationModel> get visibleStations {
    final list = List<StationModel>.from(_nearbyStations);
    double priceOf(StationModel s) {
      return switch (_fuelType) {
        FuelType.regular => s.regularPrice,
        FuelType.premium => s.premiumPrice,
        FuelType.diesel => s.dieselPrice,
      };
    }

    final filtered = _onlyWithPrices
        ? list.where((s) => priceOf(s) > 0).toList()
        : list;

    // Cheapest first; stations with no price for this fuel go last.
    double rank(StationModel s) {
      final p = priceOf(s);
      return p > 0 ? p : double.infinity;
    }

    filtered.sort((a, b) => rank(a).compareTo(rank(b)));
    return filtered;
  }

  /// Start listening to real-time station updates (the directory
  /// document: every station in one read).
  void listenToStations() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _stationsSubscription?.cancel();
    _stationsSubscription = _firebaseService.directoryStream().listen(
      (stations) {
        _nearbyStations = stations;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Could not load nearby stations.';
        _isLoading = false;
        if (kDebugMode) print('Stations stream error: $e');
        notifyListeners();
      },
    );
  }

  /// One-time fetch (fallback / manual refresh)
  Future<void> fetchNearbyStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _nearbyStations = await _firebaseService.getDirectory();
    } catch (e) {
      _errorMessage = 'Could not load nearby stations.';
      if (kDebugMode) {
        print("Error fetching stations: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hours, phone and website live on the station document, not in the
  /// directory; fetched when a station is opened.
  Future<StationModel?> loadDetails(String stationId) async {
    try {
      return await _firebaseService.getStation(stationId);
    } on Exception catch (e) {
      if (kDebugMode) print('Station details failed: $e');
      return null;
    }
  }

  void setFuelType(FuelType type) {
    if (_fuelType == type) return;
    _fuelType = type;
    notifyListeners();
  }

  void toggleOnlyWithPrices() {
    _onlyWithPrices = !_onlyWithPrices;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stationsSubscription?.cancel();
    super.dispose();
  }
}
