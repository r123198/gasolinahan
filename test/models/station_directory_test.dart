import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_directory.dart';
import 'package:gasolinahan/models/station_model.dart';

void main() {
  final shell = StationModel(
    id: 'shell1',
    name: 'Shell Tibanga',
    brand: 'Shell',
    address: 'Tibanga, Iligan City',
    city: 'Iligan City',
    latitude: 8.24,
    longitude: 124.25,
    regularPrice: 61.2,
    premiumPrice: 0,
    dieselPrice: 58.9,
    lastUpdated: DateTime.utc(2026, 11, 1, 8),
    productPrices: const {'FuelSave Unleaded': 61.2},
    amenities: const StationAmenities(
      restroom: true,
      convenienceStore: false,
      open24Hours: true,
    ),
    rating: 4.3,
    reviewCount: 120,
    nearbyStore: '7-Eleven',
  );

  test('a station survives the round trip through a directory entry', () {
    final entry = encodeDirectoryEntry(shell);
    expect(entry['n'], 'Shell Tibanga');
    expect(entry['r'], 61.2);
    expect(entry.containsKey('p'), isFalse); // unreported price left out
    expect(entry['am'], {'rr': 1, 'cs': 0, 'h24': 1});
    expect(entry['u'], isA<Timestamp>());
    expect(entry.containsKey('st'), isFalse); // operational is the default

    final back = decodeDirectoryEntry('shell1', entry);
    expect(back.id, 'shell1');
    expect(back.displayName, 'Shell Tibanga');
    expect(back.city, 'Iligan City');
    expect(back.regularPrice, 61.2);
    expect(back.dieselPrice, 58.9);
    expect(back.productPrices, {'FuelSave Unleaded': 61.2});
    expect(back.lastUpdated.toUtc(), DateTime.utc(2026, 11, 1, 8));
    expect(back.amenities.restroom, isTrue);
    expect(back.amenities.convenienceStore, isFalse);
    expect(back.amenities.airPump, isNull); // not listed stays unknown
    expect(back.amenities.open24Hours, isTrue);
    expect(back.rating, 4.3);
    expect(back.reviewCount, 120);
    expect(back.nearbyStore, '7-Eleven');
    expect(back.hasPrices, isTrue);
  });

  test('decodes the sample the import script writes', () {
    final file = File('tool/stations/sample_directory.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final stations = decodeDirectory(data);
    expect(stations.length, greaterThanOrEqualTo(5));

    final soti = stations.firstWhere((s) => s.name.startsWith('Soti Fuel'));
    expect(soti.id, 'ChIJgRqEywqfVTIReNDbWvqhB9E');
    expect(soti.brand, ''); // "Independent / other" became blank
    expect(soti.displayName, 'Soti Fuel Station - Baloi Branch');
    expect(soti.city, 'Baloi');
    expect(soti.isPlaced, isTrue);
    expect(soti.hasPrices, isFalse);
    expect(soti.lastUpdated, StationModel.epoch);
    expect(soti.amenities.restroom, isTrue);
    expect(soti.amenities.carWash, isTrue);
    expect(soti.amenities.convenienceStore, isNull);
    expect(soti.rating, 4.6);
    expect(soti.reviewCount, 5);

    final aiji = stations.firstWhere((s) => s.name == 'Aiji Fuel');
    expect(aiji.brand, 'Aiji');
    expect(aiji.amenities.open24Hours, isFalse); // hours listed, not 24h
  });

  test('decodeDirectory tolerates a missing or odd document', () {
    expect(decodeDirectory(null), isEmpty);
    expect(decodeDirectory({'stations': 'nope'}), isEmpty);
    expect(
      decodeDirectory({
        'stations': {
          'ok': {'n': 'A', 'b': '', 'la': 1, 'lo': 2},
          'bad': 'not a map',
        },
      }).map((s) => s.id),
      ['ok'],
    );
  });

  test('a price report merges only its prices into a known station', () {
    final update = directoryPriceUpdate(
      stationId: 'shell1',
      stationExists: true,
      regularPrice: 62,
      productPrices: const {'V-Power Gasoline': 68.1},
      name: 'ignored',
      latitude: 9,
      lastUpdated: 'ts',
    );
    expect(update, {
      'stations': {
        'shell1': {
          'r': 62.0,
          'pp': {'V-Power Gasoline': 68.1},
          'u': 'ts',
        },
      },
    });
  });

  test('a report for a new station also places and names it', () {
    final update = directoryPriceUpdate(
      stationId: 'new1',
      stationExists: false,
      dieselPrice: 57.5,
      name: 'Petron Mayapa',
      brand: 'Petron',
      latitude: 14.2,
      longitude: 121.1,
      lastUpdated: 'ts',
    );
    expect((update['stations'] as Map)['new1'], {
      'd': 57.5,
      'u': 'ts',
      'n': 'Petron Mayapa',
      'b': 'Petron',
      'la': 14.2,
      'lo': 121.1,
    });
  });
}
