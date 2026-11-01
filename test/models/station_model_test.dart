import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';

void main() {
  group('StationAmenities', () {
    test('reads only booleans and writes only known values', () {
      final a = StationAmenities.fromMap({
        'restroom': true,
        'airPump': false,
        'atm': 'yes', // not a bool: ignored
      });
      expect(a.restroom, isTrue);
      expect(a.airPump, isFalse);
      expect(a.atm, isNull);
      expect(a.toMap(), {'restroom': true, 'airPump': false});
      expect(a.hasAny, isTrue);
      expect(StationAmenities.none.hasAny, isFalse);
      expect(StationAmenities.fromMap(null).hasAny, isFalse);
    });
  });

  group('StationModel.fromMap', () {
    test('reads the imported fields and defaults the rest', () {
      final s = StationModel.fromMap({
        'name': 'Blu Energy Gusa',
        'brand': 'Blu Energy',
        'address': 'Gusa, CDO',
        'city': 'Cagayan de Oro City',
        'latitude': 8.49,
        'longitude': 124.69,
        'amenities': {'restroom': true, 'open24Hours': true},
        'openingHours': {'Monday': 'Open 24 hours'},
        'phone': '+63 88 123 4567',
        'website': 'https://bluenergy.ph',
        'mapsUrl': 'https://maps.google.com/?q=x',
        'rating': 4,
        'reviewCount': 12,
        'status': 'temporarily_closed',
        'nearbyStore': '7-Eleven',
      }, 'blu1');
      expect(s.city, 'Cagayan de Oro City');
      expect(s.amenities.open24Hours, isTrue);
      expect(s.openingHours['Monday'], 'Open 24 hours');
      expect(s.phone, '+63 88 123 4567');
      expect(s.rating, 4.0);
      expect(s.reviewCount, 12);
      expect(s.isOpen, isFalse);
      expect(s.nearbyStore, '7-Eleven');
      expect(s.hasPrices, isFalse);
      expect(s.lastUpdated, StationModel.epoch);
      expect(s.isPlaced, isTrue);
    });

    test('older documents still read as before', () {
      final s = StationModel.fromMap({
        'name': 'Petron Mayapa',
        'brand': 'Petron',
        'regularPrice': 59.8,
        'lastUpdated': Timestamp.fromDate(DateTime.utc(2026, 10, 28)),
      }, 'p1');
      expect(s.hasPrices, isTrue);
      expect(s.lastUpdated.toUtc(), DateTime.utc(2026, 10, 28));
      expect(s.isOpen, isTrue);
      expect(s.amenities.hasAny, isFalse);
      expect(s.isPlaced, isFalse);
    });
  });

  test('toMap leaves out what is unknown', () {
    final s = StationModel(
      id: 'x',
      name: 'X',
      brand: '',
      address: '',
      latitude: 1,
      longitude: 2,
      regularPrice: 0,
      premiumPrice: 0,
      dieselPrice: 0,
      lastUpdated: StationModel.epoch,
    );
    final map = s.toMap();
    expect(map.containsKey('lastUpdated'), isFalse);
    expect(map.containsKey('amenities'), isFalse);
    expect(map.containsKey('status'), isFalse);
    expect(map.containsKey('rating'), isFalse);
  });
}
