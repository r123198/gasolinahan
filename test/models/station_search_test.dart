import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/station_model.dart';
import 'package:gasolinahan/models/station_search.dart';

StationModel station(String name, String brand, double lat, double lng) =>
    StationModel.fromMap({
      'name': name,
      'brand': brand,
      'latitude': lat,
      'longitude': lng,
    }, name);

void main() {
  // Around Iligan: the user is at the plaza; far = Tibanga, farther = Saray.
  final plaza = station('Petron Plaza', 'Petron', 8.2280, 124.2440);
  final tibanga = station('Shell Tibanga', 'Shell', 8.2400, 124.2500);
  final saray = station('Seaoil Saray', 'Seaoil', 8.2340, 124.2450);
  final unplaced = station('Caltex Somewhere', 'Caltex', 0, 0);

  group('nearestFirst', () {
    test('orders by distance and puts unplaced stations last', () {
      final ordered = nearestFirst(
        [tibanga, unplaced, saray, plaza],
        userLat: 8.2281,
        userLng: 124.2441,
      );
      expect(ordered.map((s) => s.name), [
        'Petron Plaza',
        'Seaoil Saray',
        'Shell Tibanga',
        'Caltex Somewhere',
      ]);
    });

    test('keeps the given order without a fix', () {
      expect(nearestFirst([tibanga, plaza]).map((s) => s.name), [
        'Shell Tibanga',
        'Petron Plaza',
      ]);
    });
  });

  test('distanceToStation is null without a fix or coordinates', () {
    expect(distanceToStation(plaza, null, null), isNull);
    expect(distanceToStation(unplaced, 8.2, 124.2), isNull);
    expect(distanceToStation(plaza, 8.2280, 124.2440), closeTo(0, 1));
  });

  group('brandsAmong', () {
    test('counts the registry spelling once, most common first', () {
      final brands = brandsAmong([
        station('A', 'SeaOil', 1, 1),
        station('B', 'seaoil', 1, 1),
        station('C', 'Petron', 1, 1),
        station('D', '', 1, 1),
        station('E', 'Shell', 1, 1),
      ]);
      expect(brands, ['Seaoil', 'Petron', 'Shell']);
    });
  });

  group('StationFilter', () {
    StationModel withAmenities(String name, Map<String, bool> am) =>
        StationModel.fromMap({
          'name': name,
          'latitude': 1,
          'longitude': 1,
          'amenities': am,
        }, name);

    test('keeps only stations listing every chosen amenity', () {
      final both = withAmenities('both', {'restroom': true, 'airPump': true});
      final restroomOnly = withAmenities('rr', {'restroom': true});
      final unknown = withAmenities('none', {});
      final all = [both, restroomOnly, unknown];
      expect(applyFilters(all, {}), all);
      expect(applyFilters(all, {StationFilter.restroom}).map((s) => s.name), [
        'both',
        'rr',
      ]);
      expect(
        applyFilters(all, {
          StationFilter.restroom,
          StationFilter.airPump,
        }).map((s) => s.name),
        ['both'],
      );
    });

    test('a store next door counts as a convenience store', () {
      final nextDoor = StationModel.fromMap({
        'name': 'x',
        'latitude': 1,
        'longitude': 1,
        'nearbyStore': '7-Eleven',
      }, 'x');
      expect(StationFilter.convenienceStore.matches(nextDoor), isTrue);
    });
  });

  group('pushRecentSearch', () {
    test('moves a repeated query to the front, ignoring case', () {
      expect(pushRecentSearch(['shell', 'petron'], 'Petron'), [
        'Petron',
        'shell',
      ]);
    });

    test('ignores blanks and caps the list', () {
      expect(pushRecentSearch(['a'], '  '), ['a']);
      final many = List.generate(maxRecentSearches, (i) => 'q$i');
      final next = pushRecentSearch(many, 'new');
      expect(next.length, maxRecentSearches);
      expect(next.first, 'new');
      expect(next.contains('q${maxRecentSearches - 1}'), isFalse);
    });
  });
}
