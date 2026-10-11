import '../models/trip_model.dart';
import '../models/trip_point.dart';
import 'offline_database_service.dart';
import 'trip_tracker.dart';

/// Local persistence for recorded trips.
///
/// A trip is written as "active" the moment it starts and each GPS point is
/// saved as it arrives, so a drive survives the app being killed. Active trips
/// left over from a previous run are recovered on the next launch.
class TripService {
  /// Starts a trip owned by [ownerUid] (null when signed out).
  Future<int> beginActive(
    DateTime startedAt,
    List<TripPoint> points, {
    String? ownerUid,
  }) async {
    final db = await OfflineDatabaseService.database;
    return db.transaction((txn) async {
      final id = await txn.insert('trips', {
        'startedAt': startedAt.toIso8601String(),
        'endedAt': startedAt.toIso8601String(),
        'distanceMeters': 0,
        'isActive': 1,
        'ownerUid': ownerUid,
      });
      final batch = txn.batch();
      for (final p in points) {
        batch.insert('trip_points', _pointRow(id, p));
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  Future<void> appendPoint(int tripId, TripPoint point) async {
    final db = await OfflineDatabaseService.database;
    await db.insert('trip_points', _pointRow(tripId, point));
  }

  /// Marks an active trip as finished with its final totals.
  Future<void> finalize(int tripId, FinishedTrip trip) async {
    final db = await OfflineDatabaseService.database;
    await db.update(
      'trips',
      {
        'endedAt': trip.endedAt.toIso8601String(),
        'distanceMeters': trip.distanceMeters,
        'isActive': 0,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<List<int>> activeTripIds() async {
    final db = await OfflineDatabaseService.database;
    final rows = await db.query(
      'trips',
      columns: ['id'],
      where: 'isActive = 1',
    );
    return rows.map((r) => r['id'] as int).toList();
  }

  /// Finished trips for [ownerUid] plus unowned ones; signed out
  /// ([ownerUid] null), only the unowned ones.
  Future<List<Trip>> getAll({String? ownerUid}) async {
    final db = await OfflineDatabaseService.database;
    final rows = await db.query(
      'trips',
      where: ownerUid == null
          ? 'isActive = 0 AND ownerUid IS NULL'
          : 'isActive = 0 AND (ownerUid = ? OR ownerUid IS NULL)',
      whereArgs: ownerUid == null ? null : [ownerUid],
      orderBy: 'startedAt DESC',
    );
    return rows.map(Trip.fromMap).toList();
  }

  /// Gives trips saved before accounts were tracked (or while signed out)
  /// to [uid], as fill-ups are claimed on sign-in.
  Future<void> claimUnowned(String uid) async {
    final db = await OfflineDatabaseService.database;
    await db.update('trips', {'ownerUid': uid}, where: 'ownerUid IS NULL');
  }

  Future<List<TripPoint>> pointsFor(int tripId) async {
    final db = await OfflineDatabaseService.database;
    final rows = await db.query(
      'trip_points',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'id ASC',
    );
    return rows.map(TripPoint.fromMap).toList();
  }

  Future<void> delete(int tripId) async {
    final db = await OfflineDatabaseService.database;
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  Map<String, Object?> _pointRow(int tripId, TripPoint p) => {
    'tripId': tripId,
    'latitude': p.latitude,
    'longitude': p.longitude,
    'timestamp': p.timestamp.toIso8601String(),
  };
}
