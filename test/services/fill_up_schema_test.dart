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

  test('a v4 fill_ups table gets the three v5 columns added', () {
    expect(missingFillUpColumnStatements(v4Columns), [
      'ALTER TABLE fill_ups ADD COLUMN pricePerLiter REAL',
      "ALTER TABLE fill_ups ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE fill_ups ADD COLUMN photoPaths TEXT NOT NULL DEFAULT '[]'",
    ]);
  });

  test('only the columns that are missing are added', () {
    expect(
      missingFillUpColumnStatements({...v4Columns, 'pricePerLiter', 'notes'}),
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
      }),
      isEmpty,
    );
  });
}
