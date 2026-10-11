import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import '../models/brand_registry.dart';
import '../models/points_rules.dart';
import '../models/price_board_parser.dart';
import '../models/report_matching.dart';
import '../models/report_points_context.dart';
import '../models/report_upload.dart';
import '../models/station_model.dart';
import '../services/firebase_service.dart';
import '../services/geo.dart';
import '../services/offline_database_service.dart';
import '../services/sync_service.dart';

enum ReportStep { idle, capturing, processing, locating, form, submitting }

class ReportViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final OfflineDatabaseService _offlineDb = OfflineDatabaseService();
  final SyncService _syncService = SyncService();
  final ImagePicker _picker = ImagePicker();
  final Location _location = Location();

  ReportStep _step = ReportStep.idle;
  String _statusMessage = '';
  String? _errorMessage;
  String? _imagePath;
  bool _savedOffline = false;

  // Anti-abuse: rate limiting
  DateTime? _lastSubmission;
  static const _minSubmitInterval = Duration(minutes: 2);

  /// Loading the user's report history mustn't hold up a submit for long.
  static const _historyTimeout = Duration(seconds: 5);
  static const _historyLimit = 60;

  /// A GPS fix that never comes mustn't leave the scan spinning.
  static const _locationTimeout = Duration(seconds: 15);

  /// The user's earlier reports (sent and queued), loaded as the form
  /// opens for the points preview; null when unknown.
  List<PastReport>? _history;

  /// Points earned by the last submitted report (for the success screen).
  PointsAward? _lastAward;

  // OCR results
  double _regularPrice = 0.0;
  double _premiumPrice = 0.0;
  double _dieselPrice = 0.0;

  /// Price per product of the brand (e.g. {"XCS": 61.2}); empty for an
  /// unknown brand, where only the three grade prices are used.
  Map<String, double> _productPrices = const {};
  String _rawOcrText = '';

  // Location
  double _latitude = 0.0;
  double _longitude = 0.0;

  // Form fields
  String _stationName = '';
  String _brand = '';
  String _stationId = '';

  // OCR-detected brand
  BrandInfo? _detectedBrand;

  // Nearby stations sorted by distance
  List<StationModel> _nearbyStations = [];
  Map<String, double> _stationDistances = {};
  StationModel? _matchedStation;

  // Getters
  ReportStep get step => _step;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get imagePath => _imagePath;
  double get regularPrice => _regularPrice;
  double get premiumPrice => _premiumPrice;
  double get dieselPrice => _dieselPrice;
  Map<String, double> get productPrices => _productPrices;
  String get rawOcrText => _rawOcrText;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get stationName => _stationName;
  String get brand => _brand;
  String get stationId => _stationId;
  bool get savedOffline => _savedOffline;
  List<StationModel> get nearbyStations => _nearbyStations;
  Map<String, double> get stationDistances => _stationDistances;
  StationModel? get matchedStation => _matchedStation;
  BrandInfo? get detectedBrand => _detectedBrand;
  PointsAward? get lastAward => _lastAward;
  bool get isNearStation =>
      _matchedStation != null &&
      (_stationDistances[_matchedStation!.id] ?? double.infinity) <= 200;

  // Setters for form editing
  void setRegularPrice(double v) {
    _regularPrice = v;
    notifyListeners();
  }

  void setPremiumPrice(double v) {
    _premiumPrice = v;
    notifyListeners();
  }

  void setDieselPrice(double v) {
    _dieselPrice = v;
    notifyListeners();
  }

  /// Replaces the per-product prices (0 or less drops a product) and, for a
  /// known [brand], derives each grade price from its first priced product.
  void setProductPrices(Map<String, double> prices, {BrandInfo? brand}) {
    _productPrices = Map.unmodifiable({
      for (final MapEntry(:key, :value) in prices.entries)
        if (value > 0) key: value,
    });
    if (brand != null && _productPrices.isNotEmpty) {
      final grades = gradesFromProducts(brand, _productPrices);
      _regularPrice = grades[FuelCategory.regular] ?? 0;
      _premiumPrice = grades[FuelCategory.premium] ?? 0;
      _dieselPrice = grades[FuelCategory.diesel] ?? 0;
    }
    notifyListeners();
  }

  void setStationName(String v) {
    _stationName = v;
    notifyListeners();
  }

  void setBrand(String v) {
    _brand = v;
    notifyListeners();
  }

  void setStationId(String v) {
    _stationId = v;
    notifyListeners();
  }

  /// Full capture-to-form flow (legacy — uses image_picker)
  Future<bool> captureAndProcess() async {
    _errorMessage = null;
    _savedOffline = false;

    // Step 1: Capture image
    _step = ReportStep.capturing;
    _statusMessage = 'Opening camera...';
    notifyListeners();

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null) {
        _step = ReportStep.idle;
        notifyListeners();
        return false; // user cancelled
      }
      _imagePath = photo.path;
    } catch (e) {
      _errorMessage = 'Could not open camera: $e';
      _step = ReportStep.idle;
      notifyListeners();
      return false;
    }

    return processImage(_imagePath!);
  }

  /// Process a captured image: verify → OCR → location → station matching → form
  Future<bool> processImage(String imagePath) async {
    _errorMessage = null;
    _savedOffline = false;
    _imagePath = imagePath;

    // Step 0: Verify image authenticity
    _step = ReportStep.processing;
    _statusMessage = 'Verifying image...';
    notifyListeners();

    try {
      await _verifyImage(imagePath);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _step = ReportStep.idle;
      notifyListeners();
      return false;
    }

    // Step 1: OCR processing
    _statusMessage = 'Reading prices from image...';
    notifyListeners();

    try {
      await _runOcr(imagePath);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _step = ReportStep.idle;
      notifyListeners();
      return false;
    }

    // Step 2: Get location
    _step = ReportStep.locating;
    _statusMessage = 'Getting your location...';
    notifyListeners();

    try {
      await _getLocation();
    } catch (e) {
      if (kDebugMode) print('Location error: $e');
    }

    // Step 2b: Match to nearest station
    _statusMessage = 'Finding nearby stations...';
    notifyListeners();
    await _matchNearbyStations();
    _history = await _loadHistory();

    // Step 2c: Must be near at least one station
    if (_nearbyStations.isEmpty && _latitude != 0 && _longitude != 0) {
      _errorMessage =
          'No gas stations found nearby. You need to be at or near a station to submit a report.';
      _step = ReportStep.idle;
      notifyListeners();
      return false;
    }

    // Step 3: Ready for form
    _step = ReportStep.form;
    _statusMessage = '';
    notifyListeners();
    return true;
  }

  /// Verify the image is a fresh camera capture, not a screenshot or downloaded photo
  Future<void> _verifyImage(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('Image file not found.');
    }

    // 1. Check file freshness — must have been created within the last 2 minutes
    final stat = file.statSync();
    final age = DateTime.now().difference(stat.modified);
    if (age.inSeconds > 120) {
      throw Exception(
        'This image appears to be old. Please take a fresh photo of the price board.',
      );
    }

    // 2. Check EXIF data for camera hardware markers
    try {
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);

      if (exifData.isNotEmpty) {
        // Screenshots typically lack Make/Model EXIF tags
        final hasCamera =
            exifData.containsKey('Image Make') ||
            exifData.containsKey('Image Model') ||
            exifData.containsKey('EXIF FocalLength') ||
            exifData.containsKey('EXIF ExposureTime');

        if (!hasCamera) {
          throw Exception(
            'This image doesn\'t appear to be taken with a camera. '
            'Please take a photo directly at the station.',
          );
        }
      }
      // Empty EXIF is OK — some camera plugins strip it
    } catch (e) {
      // If it's our own exception, rethrow
      if (e is Exception &&
          e.toString().contains('doesn\'t appear to be taken')) {
        rethrow;
      }
      // Otherwise EXIF parsing failed — allow it (some formats don't have EXIF)
      if (kDebugMode) print('EXIF check skipped: $e');
    }

    // 3. Check image dimensions — screenshots of price boards from phones
    // tend to be exact screen resolution. Real camera photos are much larger.
    final decodedImage = await _decodeImageSize(imagePath);
    final pixels = decodedImage.width * decodedImage.height;
    // Real camera photos are typically 2+ megapixels
    // Very small images are suspicious (screenshots, thumbnails)
    if (pixels < 500000) {
      throw Exception(
        'Image resolution is too low. Please take a clear, full-resolution photo.',
      );
    }
  }

  /// Decode image dimensions
  static Future<_ImageSize> _decodeImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = _ImageSize(descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  Future<void> _runOcr(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      _rawOcrText = recognizedText.text;

      _regularPrice = 0.0;
      _premiumPrice = 0.0;
      _dieselPrice = 0.0;
      _productPrices = const {};
      _detectedBrand = BrandRegistry.detectFromOcr(recognizedText.text);
      if (_detectedBrand != null) {
        _brand = _detectedBrand!.name;
      }

      // Validate this looks like a fuel price board before parsing
      if (!looksLikePriceBoard(recognizedText.text)) {
        throw Exception(
          'This doesn\'t look like a fuel price board. '
          'Please take a clear photo of the station\'s price display.',
        );
      }

      final board = parsePriceBoard([
        for (final block in recognizedText.blocks) block.text,
      ], brand: _detectedBrand);
      _regularPrice = board.regular;
      _premiumPrice = board.premium;
      _dieselPrice = board.diesel;
      final brand = _detectedBrand;
      if (brand != null) {
        _productPrices = Map.unmodifiable(productPricesForForm(brand, board));
      }

      // After parsing, require at least one valid price was extracted
      if (_regularPrice == 0 && _premiumPrice == 0 && _dieselPrice == 0) {
        throw Exception(
          'Could not find any fuel prices in the image. '
          'Make sure the price board is clearly visible and try again.',
        );
      }
    } finally {
      await textRecognizer.close();
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        return;
      }
    }

    final loc = await _location.getLocation().timeout(_locationTimeout);
    _latitude = loc.latitude ?? 0.0;
    _longitude = loc.longitude ?? 0.0;
  }

  Future<void> _matchNearbyStations() async {
    if (_latitude == 0 && _longitude == 0) return;

    try {
      final allStations = await _firebaseService.getStationsNear(
        _latitude,
        _longitude,
      );

      // Calculate distance to each station
      _stationDistances = {};
      for (final s in allStations) {
        if (s.latitude != 0 || s.longitude != 0) {
          _stationDistances[s.id] = haversineMeters(
            _latitude,
            _longitude,
            s.latitude,
            s.longitude,
          );
        }
      }

      // Sort by distance
      final sorted = List<StationModel>.from(allStations)
        ..sort((a, b) {
          final da = _stationDistances[a.id] ?? double.infinity;
          final db = _stationDistances[b.id] ?? double.infinity;
          return da.compareTo(db);
        });

      // Only keep stations within 5km
      _nearbyStations = sorted
          .where((s) => (_stationDistances[s.id] ?? double.infinity) <= 5000)
          .toList();

      // Auto-select the closest station within 200m whose brand fits the
      // board: a Petron board next to a closer Shell is the Petron.
      final closest = _nearbyStations
          .where(
            (s) =>
                (_stationDistances[s.id] ?? double.infinity) <= 200 &&
                brandFits(_detectedBrand, s),
          )
          .firstOrNull;
      if (closest != null) {
        _matchedStation = closest;
        _stationId = closest.id;
        _stationName = closest.name;
        if (_detectedBrand == null) _brand = closest.brand;
      }
    } catch (e) {
      if (kDebugMode) print('Station matching error: $e');
    }
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 100) return '${meters.round()}m';
    if (meters < 1000) return '${(meters / 10).round() * 10}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  /// Validate report data before submission
  String? validateReport() {
    // Rate limit — prevent spam
    if (_lastSubmission != null) {
      final elapsed = DateTime.now().difference(_lastSubmission!);
      if (elapsed < _minSubmitInterval) {
        final remaining = _minSubmitInterval - elapsed;
        return 'Please wait ${remaining.inSeconds}s before submitting another report.';
      }
    }
    // Must have at least one price
    if (_regularPrice <= 0 && _premiumPrice <= 0 && _dieselPrice <= 0) {
      return 'At least one fuel price is required.';
    }
    // Prices must be in valid Philippine range
    for (final p in [
      _regularPrice,
      _premiumPrice,
      _dieselPrice,
      ..._productPrices.values,
    ]) {
      if (p > 0 && (p < 30 || p > 150)) {
        return 'Prices must be between ₱30 and ₱150 per liter.';
      }
    }
    // Must have a station selected or named
    if (_stationId.isEmpty && _stationName.trim().isEmpty) {
      return 'Please select or enter a station name.';
    }
    // Must have valid GPS location
    if (_latitude == 0 && _longitude == 0) {
      return 'Could not determine your location. Please enable GPS and try again.';
    }
    return null; // valid
  }

  /// Submit the report — online to Firebase, offline to sqflite
  Future<bool> submitReport() async {
    // Pre-submit validation
    final validationError = validateReport();
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _step = ReportStep.submitting;
    _statusMessage = 'Submitting report...';
    _errorMessage = null;
    _savedOffline = false;
    notifyListeners();

    final now = DateTime.now();
    // Generate a clean station ID from the name, or use existing
    final slug = _stationId.isNotEmpty
        ? _stationId
        : _stationName
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_|_$'), '');
    // A name with no latin letters slugs to nothing; doc('') would throw.
    final sid = slug.isEmpty
        ? 'manual_report_${now.millisecondsSinceEpoch}'
        : slug;

    final uid = _firebaseService.currentAuthUser?.uid;
    if (uid == null) {
      _errorMessage = 'You are signed out. Sign in to send reports.';
      _step = ReportStep.form;
      notifyListeners();
      return false;
    }

    final history = await _loadHistory() ?? _history;
    final context = buildReportContext(
      _pointsInput(sid, now, history: history),
    );
    final award = pointsForReport(context);
    _lastAward = award;
    final upload = ReportUpload(
      reportId: _firebaseService.newReportId(),
      userId: uid,
      stationId: sid,
      stationName: _stationName,
      brand: _brand,
      latitude: _latitude,
      longitude: _longitude,
      regularPrice: _regularPrice,
      premiumPrice: _premiumPrice,
      dieselPrice: _dieselPrice,
      productPrices: _productPrices,
      timestamp: now,
      points: award.points,
      pointsReason: describeAward(context),
      isPending: award.isPending,
    );

    // Offline, or Firebase failing / too slow: queue it under the same
    // report id (see ReportWriter) and let SyncService send it later.
    try {
      await _firebaseService.submitPriceReport(upload);
    } on Exception catch (e) {
      if (kDebugMode) print('Report not sent, saving offline: $e');
      try {
        await _saveOffline(upload);
        _savedOffline = true;
      } on Exception catch (offlineError) {
        _errorMessage = 'Could not save report: $offlineError';
        _step = ReportStep.form;
        notifyListeners();
        return false;
      }
    }
    _history = [...?history, upload.toPastReport()];
    _lastSubmission = DateTime.now();
    _step = ReportStep.idle;
    notifyListeners();
    return true;
  }

  /// Award for the form's points hint, using the history loaded as the
  /// form opened (so daily limits and already-rewarded stations apply).
  PointsAward estimateAward({
    required String stationId,
    required Map<String, double> productPrices,
    required Map<FuelCategory, double> gradePrices,
  }) {
    final input = _pointsInput(
      stationId,
      DateTime.now(),
      history: _history,
      productPrices: productPrices,
      gradePrices: gradePrices,
    );
    return pointsForReport(buildReportContext(input));
  }

  ReportPointsInput _pointsInput(
    String stationId,
    DateTime now, {
    required List<PastReport>? history,
    Map<String, double>? productPrices,
    Map<FuelCategory, double>? gradePrices,
  }) {
    final existing = _nearbyStations
        .where((s) => s.id == stationId)
        .firstOrNull;
    Map<FuelCategory, double> gradesOf(StationModel s) => {
      FuelCategory.regular: s.regularPrice,
      FuelCategory.premium: s.premiumPrice,
      FuelCategory.diesel: s.dieselPrice,
    };
    return ReportPointsInput(
      stationId: stationId,
      productPrices: productPrices ?? _productPrices,
      gradePrices:
          gradePrices ??
          {
            FuelCategory.regular: _regularPrice,
            FuelCategory.premium: _premiumPrice,
            FuelCategory.diesel: _dieselPrice,
          },
      hasPhoto: _imagePath != null,
      userLat: _latitude,
      userLng: _longitude,
      existingStation: existing == null
          ? null
          : ReportedStationInfo(
              latitude: existing.latitude,
              longitude: existing.longitude,
              lastUpdated: existing.lastUpdated,
            ),
      nearbyGradePrices: [
        for (final s in _nearbyStations)
          if (s.id != stationId) gradesOf(s),
      ],
      history: history,
      now: now,
    );
  }

  /// The user's earlier reports, sent and still queued on this phone, or
  /// null when signed out / unreachable.
  Future<List<PastReport>?> _loadHistory() async {
    final uid = _firebaseService.currentAuthUser?.uid;
    if (uid == null) return null;
    try {
      final reports = await _firebaseService
          .getUserReports(uid, limit: _historyLimit)
          .timeout(_historyTimeout);
      final queued = await _offlineDb.getUnsyncedReports(userId: uid);
      return mergeReportHistory(reports, queued, uid: uid);
    } on Exception catch (e) {
      if (kDebugMode) print('Report history unavailable: $e');
      return null;
    }
  }

  Future<void> _saveOffline(ReportUpload r) async {
    await _offlineDb.insertPendingReport({
      'userId': r.userId,
      'stationId': r.stationId,
      'stationName': r.stationName,
      'brand': r.brand,
      'regularPrice': r.regularPrice,
      'premiumPrice': r.premiumPrice,
      'dieselPrice': r.dieselPrice,
      'latitude': r.latitude,
      'longitude': r.longitude,
      'imagePath': _imagePath,
      'timestamp': (r.timestamp ?? DateTime.now()).toIso8601String(),
      'synced': 0,
      'productPrices': jsonEncode(r.productPrices),
      'pointsAwarded': r.awardedPoints,
      'pointsReason': r.pointsReason,
      'isPending': r.isPending ? 1 : 0,
      'remoteId': r.reportId,
    });
  }

  /// Try syncing any pending offline reports
  Future<int> syncPendingReports() async {
    return _syncService.syncPendingReports();
  }

  void reset() {
    _step = ReportStep.idle;
    _statusMessage = '';
    _errorMessage = null;
    _imagePath = null;
    _regularPrice = 0.0;
    _premiumPrice = 0.0;
    _dieselPrice = 0.0;
    _productPrices = const {};
    _rawOcrText = '';
    _latitude = 0.0;
    _longitude = 0.0;
    _stationName = '';
    _brand = '';
    _stationId = '';
    _savedOffline = false;
    _detectedBrand = null;
    _nearbyStations = [];
    _stationDistances = {};
    _matchedStation = null;
    _lastAward = null;
    _history = null;
    // Note: _lastSubmission is intentionally NOT reset — persists across reports
    notifyListeners();
  }
}

class _ImageSize {
  final int width;
  final int height;
  const _ImageSize(this.width, this.height);
}
