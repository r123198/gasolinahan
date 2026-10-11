import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Columns added to fill_ups after v4, with their definitions.
const _fillUpDetailColumns = {
  'pricePerLiter': 'REAL',
  'notes': "TEXT NOT NULL DEFAULT ''",
  'photoPaths': "TEXT NOT NULL DEFAULT '[]'",
  // Cloud sync (users/{uid}/fill_ups) and per-account scoping.
  'remoteId': 'TEXT',
  'updatedAt': 'TEXT',
  'ownerUid': 'TEXT',
  // Product (e.g. "XCS") and where it was logged; coordinates never shown.
  'productName': 'TEXT',
  'latitude': 'REAL',
  'longitude': 'REAL',
  'pointsAwarded': 'INTEGER NOT NULL DEFAULT 0',
};

/// Columns added to pending_reports later: per-product prices as JSON,
/// e.g. {"XCS": 61.2, "Turbo Diesel": 55.1}.
const _pendingReportColumns = {
  'productPrices': "TEXT NOT NULL DEFAULT '{}'",
  // Points worked out when the report was made, awarded when it syncs.
  'pointsAwarded': 'INTEGER NOT NULL DEFAULT 0',
  'pointsReason': "TEXT NOT NULL DEFAULT ''",
};

/// ALTER statements that bring a fill_ups table with [existingColumns] up to
/// date. Safe to apply repeatedly: present columns are skipped.
List<String> missingFillUpColumnStatements(Set<String> existingColumns) =>
    _missingColumns('fill_ups', _fillUpDetailColumns, existingColumns);

List<String> _missingColumns(
  String table,
  Map<String, String> wanted,
  Set<String> existing,
) => [
  for (final MapEntry(key: name, value: type) in wanted.entries)
    if (!existing.contains(name)) 'ALTER TABLE $table ADD COLUMN $name $type',
];

class OfflineDatabaseService {
  static Database? _db;

  /// Shared open-and-check step, so concurrent first callers don't both
  /// run the column check (a duplicate ALTER would fail). A hot reload keeps
  /// an already-open [_db] — so onUpgrade never runs — but starts this
  /// field fresh, so the check still happens once.
  static Future<Database>? _ready;

  static Future<Database> get database => _ready ??= _openChecked();

  static Future<Database> _openChecked() async {
    try {
      final db = _db ??= await _initDb();
      await _ensureFillUpColumns(db);
      return db;
    } catch (_) {
      _ready = null; // let the next call retry instead of caching a failure
      rethrow;
    }
  }

  static Future<void> _ensureFillUpColumns(Database db) async {
    await _ensureColumns(db, 'fill_ups', _fillUpDetailColumns);
    await _ensureColumns(db, 'pending_reports', _pendingReportColumns);
  }

  static Future<void> _ensureColumns(
    Database db,
    String table,
    Map<String, String> wanted,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final existing = {for (final row in info) row['name'] as String};
    for (final statement in _missingColumns(table, wanted, existing)) {
      await db.execute(statement);
    }
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'gasolinahan.db');
    return openDatabase(
      path,
      version: 8,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createPendingReports(db);
        await _createFillUps(db);
        await _createTrips(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createFillUps(db);
        if (oldVersion < 3) await _createTrips(db);
        if (oldVersion == 3) {
          await db.execute(
            'ALTER TABLE trips ADD COLUMN isActive INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 8) await _ensureFillUpColumns(db);
      },
    );
  }

  static Future<void> _createPendingReports(Database db) {
    return db.execute('''
          CREATE TABLE pending_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            stationId TEXT NOT NULL,
            stationName TEXT NOT NULL,
            brand TEXT NOT NULL,
            regularPrice REAL NOT NULL DEFAULT 0,
            premiumPrice REAL NOT NULL DEFAULT 0,
            dieselPrice REAL NOT NULL DEFAULT 0,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            imagePath TEXT,
            timestamp TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            productPrices TEXT NOT NULL DEFAULT '{}',
            pointsAwarded INTEGER NOT NULL DEFAULT 0,
            pointsReason TEXT NOT NULL DEFAULT ''
          )
        ''');
  }

  static Future<void> _createTrips(Database db) async {
    await db.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startedAt TEXT NOT NULL,
            endedAt TEXT NOT NULL,
            distanceMeters REAL NOT NULL,
            isActive INTEGER NOT NULL DEFAULT 0
          )
        ''');
    await db.execute('''
          CREATE TABLE trip_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tripId INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_trip_points_trip ON trip_points (tripId)',
    );
  }

  static Future<void> _createFillUps(Database db) {
    return db.execute('''
          CREATE TABLE fill_ups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stationId TEXT NOT NULL,
            stationName TEXT NOT NULL,
            brand TEXT NOT NULL,
            fuelType TEXT NOT NULL,
            amountSpent REAL NOT NULL,
            liters REAL,
            odometerKm REAL NOT NULL,
            timestamp TEXT NOT NULL,
            pricePerLiter REAL,
            notes TEXT NOT NULL DEFAULT '',
            photoPaths TEXT NOT NULL DEFAULT '[]',
            remoteId TEXT,
            updatedAt TEXT,
            ownerUid TEXT,
            productName TEXT,
            latitude REAL,
            longitude REAL,
            pointsAwarded INTEGER NOT NULL DEFAULT 0
          )
        ''');
  }

  Future<int> insertPendingReport(Map<String, dynamic> report) async {
    final db = await database;
    return db.insert('pending_reports', report);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReports() async {
    final db = await database;
    return db.query('pending_reports', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      'pending_reports',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> unsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_reports WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
