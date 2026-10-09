import '../models/fill_up_model.dart';
import 'offline_database_service.dart';

/// Local persistence for the user's fill-up log.
class FillUpService {
  static const _table = 'fill_ups';

  Future<List<FillUp>> getAll() async {
    final db = await OfflineDatabaseService.database;
    final rows = await db.query(_table, orderBy: 'timestamp DESC');
    return rows.map(FillUp.fromMap).toList();
  }

  Future<int> insert(FillUp fillUp) async {
    final db = await OfflineDatabaseService.database;
    return db.insert(_table, fillUp.toMap());
  }

  Future<void> delete(int id) async {
    final db = await OfflineDatabaseService.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
