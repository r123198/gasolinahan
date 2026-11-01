import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/brand_registry.dart';

void main() {
  group('BrandRegistry.inferFromName', () {
    test('finds the brand inside a typed station name', () {
      expect(BrandRegistry.inferFromName('Petron Mayapa')?.name, 'Petron');
      expect(BrandRegistry.inferFromName('shell edsa')?.name, 'Shell');
    });

    test('understands spaced or joined spellings', () {
      expect(BrandRegistry.inferFromName('Sea Oil Real')?.name, 'Seaoil');
      expect(BrandRegistry.inferFromName('FlyingV Calamba')?.name, 'Flying V');
    });

    test('does not match a brand hidden inside another word', () {
      expect(BrandRegistry.inferFromName('Totalis Gas'), isNull);
    });

    test('returns null for unknown stations', () {
      expect(BrandRegistry.inferFromName('Kuya Ben Gasoline'), isNull);
    });
  });

  group('BrandRegistry.match', () {
    test('prefers the stored brand, then the station name', () {
      expect(
        BrandRegistry.match('Caltex', stationName: 'Petron X')?.name,
        'Caltex',
      );
      expect(BrandRegistry.match('', stationName: 'Petron X')?.name, 'Petron');
    });
  });

  test('every brand has an emblem mark next to its logo', () {
    for (final b in BrandRegistry.brands) {
      expect(b.markPath, startsWith('assets/images/brand_marks/'));
      expect(File(b.markPath).existsSync(), isTrue, reason: b.markPath);
      expect(File(b.logoPath).existsSync(), isTrue, reason: b.logoPath);
    }
  });

  test('reads the imported Northern Mindanao brands from station names', () {
    expect(
      BrandRegistry.inferFromName('RM C PETROL CARMEN')?.name,
      'RM C Petrol',
    );
    expect(BrandRegistry.inferFromName('BLU energy')?.name, 'Blu Energy');
    expect(BrandRegistry.inferFromName('Velox - Masterson')?.name, 'Velox');
    expect(
      BrandRegistry.inferFromName('PETRO DE ORO CORPORATION')?.name,
      'Insular Oil',
    );
    expect(
      BrandRegistry.findByName('TecFuel')?.markPath,
      endsWith('tecfuel.jpeg'),
    );
  });
}
