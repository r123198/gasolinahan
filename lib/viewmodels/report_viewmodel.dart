import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import '../models/brand_registry.dart';
import '../models/station_model.dart';
import '../services/firebase_service.dart';
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

  // OCR results
  double _regularPrice = 0.0;
  double _premiumPrice = 0.0;
  double _dieselPrice = 0.0;
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

  /// Keywords that indicate a fuel price board
  static const _fuelKeywords = [
    // Fuel types
    'regular', 'unleaded', 'premium', 'super', 'diesel', 'dsl',
    'gasoline', 'gasolin', 'gasolina', 'kerosene',
    // Octane ratings
    'ron', '87', '91', '93', '95', '97',
    'octane',
    // Brands & product names
    'v-power', 'vpower', 'xcs', 'blaze', 'turbo', 'xtreme',
    'fuel', 'petrol',
    // Board context
    'price', 'prices', 'presyo', 'per liter', 'per litre', '/l',
    'pump', 'station',
    // Philippine brands
    'shell', 'petron', 'caltex', 'seaoil', 'unioil', 'phoenix',
    'total', 'ptt', 'jetti', 'cleanfuel', 'flying v',
  ];

  /// Minimum number of fuel keywords that must appear to consider it a price board
  static const _minKeywordMatches = 2;

  Future<void> _runOcr(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      _rawOcrText = recognizedText.text;

      _regularPrice = 0.0;
      _premiumPrice = 0.0;
      _dieselPrice = 0.0;
      _detectedBrand = BrandRegistry.detectFromOcr(recognizedText.text);
      if (_detectedBrand != null) {
        _brand = _detectedBrand!.name;
      }

      // Validate this looks like a fuel price board before parsing
      if (!_looksLikePriceBoard(recognizedText.text)) {
        throw Exception(
          'This doesn\'t look like a fuel price board. '
          'Please take a clear photo of the station\'s price display.',
        );
      }

      _parseOcrPrices(recognizedText);

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

  /// Check if the OCR text contains enough fuel-related keywords to be a price board
  bool _looksLikePriceBoard(String rawText) {
    final text = rawText.toLowerCase();

    // Count how many fuel keywords appear
    int keywordHits = 0;
    final matched = <String>{};
    for (final kw in _fuelKeywords) {
      if (text.contains(kw) && !matched.contains(kw)) {
        matched.add(kw);
        keywordHits++;
      }
    }

    // Also check for price-like patterns (XX.XX or XX,XX in the 30-150 range)
    final pricePattern = RegExp(r'(\d{2,3})[.,](\d{2})');
    final priceMatches = pricePattern.allMatches(text);
    int validPriceCount = 0;
    for (final match in priceMatches) {
      final whole = int.tryParse(match.group(1)!) ?? 0;
      final decimal = int.tryParse(match.group(2)!) ?? 0;
      final price = whole + decimal / 100.0;
      if (price >= 30 && price <= 150) {
        validPriceCount++;
      }
    }

    // Must have at least 2 fuel keywords AND at least 1 valid price
    // OR at least 1 fuel keyword AND at least 2 valid prices
    return (keywordHits >= _minKeywordMatches && validPriceCount >= 1) ||
        (keywordHits >= 1 && validPriceCount >= 2);
  }

  void _parseOcrPrices(RecognizedText recognized) {
    final pricePattern = RegExp(r'(\d{2,3})[.,](\d{2})');

    // Build keyword lists — brand-specific product names + generic fallbacks
    final regularKw = <String>['regular', 'unleaded', '87', 'ron 91'];
    final premiumKw = <String>[
      'premium',
      'super',
      '93',
      '95',
      '97',
      'ron 95',
      'ron 97',
    ];
    final dieselKw = <String>['diesel', 'dsl'];

    // Add brand-specific product names if brand was detected
    if (_detectedBrand != null) {
      for (final p in _detectedBrand!.products) {
        final name = p.name.toLowerCase();
        final target = switch (p.category) {
          FuelCategory.regular => regularKw,
          FuelCategory.premium => premiumKw,
          FuelCategory.diesel => dieselKw,
        };
        target.add(name);
        // Also add individual significant words
        for (final word in name.split(' ')) {
          if (word.length > 2 && !const {'euro', 'per', 'new'}.contains(word)) {
            target.add(word);
          }
        }
      }
    } else {
      // No brand detected — add all known product names
      for (final entry in BrandRegistry.productKeywords.entries) {
        final target = switch (entry.value) {
          FuelCategory.regular => regularKw,
          FuelCategory.premium => premiumKw,
          FuelCategory.diesel => dieselKw,
        };
        target.add(entry.key);
      }
    }

    // Try to match prices to fuel types using text blocks (keyword-based)
    for (final block in recognized.blocks) {
      final blockText = block.text.toLowerCase();
      final blockPrices = <double>[];
      for (final match in pricePattern.allMatches(blockText)) {
        final whole = int.tryParse(match.group(1)!) ?? 0;
        final decimal = int.tryParse(match.group(2)!) ?? 0;
        final price = whole + decimal / 100.0;
        if (price >= 30 && price <= 150) {
          blockPrices.add(price);
        }
      }

      if (blockPrices.isEmpty) continue;

      final p = blockPrices.first;
      if (_containsAny(blockText, regularKw)) {
        _regularPrice = p;
      } else if (_containsAny(blockText, premiumKw)) {
        _premiumPrice = p;
      } else if (_containsAny(blockText, dieselKw)) {
        _dieselPrice = p;
      }
    }

    // Positional fallback — only if keyword matching found nothing
    if (_regularPrice == 0 && _premiumPrice == 0 && _dieselPrice == 0) {
      final allText = recognized.text.toLowerCase();
      final prices = <double>[];
      for (final match in pricePattern.allMatches(allText)) {
        final whole = int.tryParse(match.group(1)!) ?? 0;
        final decimal = int.tryParse(match.group(2)!) ?? 0;
        final price = whole + decimal / 100.0;
        if (price >= 30 && price <= 150) {
          prices.add(price);
        }
      }
      if (prices.length >= 2) {
        prices.sort();
        if (prices.length == 2) {
          _regularPrice = prices[0];
          _premiumPrice = prices[1];
        } else {
          _dieselPrice = prices[0];
          _regularPrice = prices[1];
          _premiumPrice = prices[2];
        }
      }
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
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

    final loc = await _location.getLocation();
    _latitude = loc.latitude ?? 0.0;
    _longitude = loc.longitude ?? 0.0;
  }

  Future<void> _matchNearbyStations() async {
    if (_latitude == 0 && _longitude == 0) return;

    try {
      final allStations = await _firebaseService.getNearbyStations();

      // Calculate distance to each station
      _stationDistances = {};
      for (final s in allStations) {
        if (s.latitude != 0 || s.longitude != 0) {
          _stationDistances[s.id] = _haversineMeters(
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

      // Auto-select the closest station if within 200m
      if (_nearbyStations.isNotEmpty) {
        final closest = _nearbyStations.first;
        final dist = _stationDistances[closest.id] ?? double.infinity;
        if (dist <= 200) {
          _matchedStation = closest;
          _stationId = closest.id;
          _stationName = closest.name;
          _brand = closest.brand;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Station matching error: $e');
    }
  }

  /// Haversine formula: distance in meters between two lat/lng points
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;

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
    for (final p in [_regularPrice, _premiumPrice, _dieselPrice]) {
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
    final sid = _stationId.isNotEmpty
        ? _stationId
        : _stationName
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_|_$'), '');

    // Try Firebase first, fall back to offline on any failure
    try {
      final success = await _firebaseService.submitPriceReport(
        sid,
        _regularPrice,
        _premiumPrice,
        diesel: _dieselPrice,
        stationName: _stationName,
        brand: _brand,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!success) throw Exception('No authenticated user');

      _lastSubmission = DateTime.now();
      _step = ReportStep.idle;
      notifyListeners();
      return true;
    } catch (e) {
      // Firebase failed — save offline instead
      if (kDebugMode) print('Firebase submit failed, saving offline: $e');
      try {
        await _saveOffline(now);
        _lastSubmission = DateTime.now();
        _savedOffline = true;
        _step = ReportStep.idle;
        notifyListeners();
        return true;
      } catch (offlineError) {
        _errorMessage = 'Could not save report: $offlineError';
        _step = ReportStep.form;
        notifyListeners();
        return false;
      }
    }
  }

  Future<void> _saveOffline(DateTime now) async {
    await _offlineDb.insertPendingReport({
      'userId': '',
      'stationId': _stationId.isEmpty
          ? 'manual_report_${now.millisecondsSinceEpoch}'
          : _stationId,
      'stationName': _stationName,
      'brand': _brand,
      'regularPrice': _regularPrice,
      'premiumPrice': _premiumPrice,
      'dieselPrice': _dieselPrice,
      'latitude': _latitude,
      'longitude': _longitude,
      'imagePath': _imagePath,
      'timestamp': now.toIso8601String(),
      'synced': 0,
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
    // Note: _lastSubmission is intentionally NOT reset — persists across reports
    notifyListeners();
  }
}

class _ImageSize {
  final int width;
  final int height;
  const _ImageSize(this.width, this.height);
}
