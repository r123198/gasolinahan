import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/services/offline_database_service.dart';

void main() {
  const v4Columns = {
    'id',
    'stationId',
    'stationName',
    'brand',
    'fuelType',
    'amountSpent',
    'liters',
    'odometerKm',
    'timestamp',
  };

  test('a v4 fill_ups table gets every newer column added', () {
    expect(missingFillUpColumnStatements(v4Columns), [
      'ALTER TABLE fill_ups ADD COLUMN pricePerLiter REAL',
      "ALTER TABLE fill_ups ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE fill_ups ADD COLUMN photoPaths TEXT NOT NULL DEFAULT '[]'",
      'ALTER TABLE fill_ups ADD COLUMN remoteId TEXT',
      'ALTER TABLE fill_ups ADD COLUMN updatedAt TEXT',
      'ALTER TABLE fill_ups ADD COLUMN ownerUid TEXT',
    ]);
  });

  test('only the columns that are missing are added', () {
    expect(
      missingFillUpColumnStatements({
        ...v4Columns,
        'pricePerLiter',
        'notes',
        'remoteId',
        'updatedAt',
        'ownerUid',
      }),
      ["ALTER TABLE fill_ups ADD COLUMN photoPaths TEXT NOT NULL DEFAULT '[]'"],
    );
  });

  test('an up-to-date table needs nothing', () {
    expect(
      missingFillUpColumnStatements({
        ...v4Columns,
        'pricePerLiter',
        'notes',
        'photoPaths',
        'remoteId',
        'updatedAt',
        'ownerUid',
      }),
      isEmpty,
    );
  });
}
