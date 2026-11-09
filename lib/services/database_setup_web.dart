import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Browsers have no native SQLite, so the same database runs from
/// web/sqlite3.wasm and is saved in IndexedDB. The wasm only loads when the
/// database is first opened, which guests never do.
void configureLocalDatabase() {
  databaseFactory = databaseFactoryFfiWeb;
}
