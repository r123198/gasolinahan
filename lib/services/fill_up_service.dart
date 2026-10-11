import '../models/fill_up_model.dart';
import 'offline_database_service.dart';

/// Local persistence for the user's fill-up log.
class FillUpService {
  static const _table = 'fill_ups';

  /// Fill-ups for [ownerUid] plus rows saved before accounts were tracked
  /// (owner null), newest first.
  Future<List<FillUp>> getAll({String? ownerUid}) async {
    final db = await OfflineDatabaseService.database;
    final rows = await db.query(
      _table,
      where: ownerUid == null
          ? 'ownerUid IS NULL'
          : 'ownerUid = ? OR ownerUid IS NULL',
      whereArgs: ownerUid == null ? null : [ownerUid],
      orderBy: 'timestamp DESC',
    );
    return rows.map(FillUp.fromMap).toList();
  }

  Future<int> insert(FillUp fillUp) async {
    final db = await OfflineDatabaseService.database;
    return db.insert(_table, fillUp.toMap());
  }

  Future<void> update(FillUp fillUp) async {
    final id = fillUp.id;
    if (id == null) throw ArgumentError('Only saved fill-ups can be updated');
    final db = await OfflineDatabaseService.database;
    await db.update(_table, fillUp.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await OfflineDatabaseService.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
