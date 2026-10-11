import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/services/place_lookup.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const here = (14.2117, 121.1653); // Mayapa, Calamba

Map<String, dynamic> overpass(List<Map<String, dynamic>> elements) => {
  'elements': elements,
};

void main() {
  group('nearestFuelStation', () {
    test('picks the closest station and reads its brand and branch', () {
      final guess = nearestFuelStation(
        overpass([
          {
            'type': 'node',
            'lat': 14.2130,
            'lon': 121.1660,
            'tags': {'amenity': 'fuel', 'brand': 'Shell', 'name': 'Shell'},
          },
          {
            'type': 'way',
            'center': {'lat': 14.2118, 'lon': 121.1654},
            'tags': {
              'amenity': 'fuel',
              'brand': 'Petron',
              'name': 'Petron Mayapa',
            },
          },
        ]),
        lat: here.$1,
        lng: here.$2,
      );
      expect(guess?.brand?.name, 'Petron');
      expect(guess?.branch, 'Mayapa');
      expect(guess?.distanceMeters, lessThan(20));
    });

    test('reads the brand from the name when the brand tag is missing', () {
      final guess = nearestFuelStation(
        overpass([
          {
            'type': 'node',
            'lat': 14.2118,
            'lon': 121.1654,
            'tags': {'amenity': 'fuel', 'name': 'Seaoil Real'},
          },
        ]),
        lat: here.$1,
        lng: here.$2,
      );
      expect(guess?.brand?.name, 'Seaoil');
      expect(guess?.branch, 'Real');
    });

    test('keeps an unknown independent station by name', () {
      final guess = nearestFuelStation(
        overpass([
          {
            'type': 'node',
            'lat': 14.2118,
            'lon': 121.1654,
            'tags': {'amenity': 'fuel', 'name': 'Kuya Ben Gasoline'},
          },
        ]),
        lat: here.$1,
        lng: here.$2,
      );
      expect(guess?.brand, isNull);
      expect(guess?.stationName, 'Kuya Ben Gasoline');
    });

    test('no stations around means no guess', () {
      expect(
        nearestFuelStation(overpass(const []), lat: here.$1, lng: here.$2),
        isNull,
      );
    });
  });

  group('areaName', () {
    test('prefers the barangay or suburb', () {
      expect(
        areaName({
          'address': {
            'road': 'National Highway',
            'suburb': 'Mayapa',
            'city': 'Calamba',
          },
        }),
        'Mayapa',
      );
    });

    test('falls back to the town or city', () {
      expect(
        areaName({
          'address': {'town': 'Los Baños', 'state': 'Laguna'},
        }),
        'Los Baños',
      );
    });

    test('nothing usable gives null', () {
      expect(areaName({'error': 'Unable to geocode'}), isNull);
    });
  });

  group('PlaceLookup', () {
    test('asks OpenStreetMap with an identifying User-Agent', () async {
      final agents = <String?>[];
      final client = MockClient((request) async {
        agents.add(request.headers['User-Agent']);
        if (request.url.host.contains('overpass')) {
          return http.Response(jsonEncode(overpass(const [])), 200);
        }
        return http.Response(
          jsonEncode({
            'address': {'suburb': 'Mayapa'},
          }),
          200,
        );
      });
      final guess = await PlaceLookup(client: client).lookUp(here.$1, here.$2);
      expect(guess?.area, 'Mayapa');
      expect(guess?.brand, isNull);
      expect(agents, everyElement(contains('com.maalam.gasolinahan')));
    });

    test('network failure gives no guess instead of an error', () async {
      final client = MockClient((_) async => http.Response('busy', 503));
      expect(
        await PlaceLookup(client: client).lookUp(here.$1, here.$2),
        isNull,
      );
    });
  });
}
