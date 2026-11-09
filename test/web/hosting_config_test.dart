import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/report_upload.dart';
import 'package:gasolinahan/models/station_directory.dart';

/// The site can't be exercised from a unit test, so these guard the settings
/// that would otherwise only fail in a visitor's browser.
void main() {
  final firebase =
      jsonDecode(File('firebase.json').readAsStringSync())
          as Map<String, dynamic>;
  final hosting = firebase['hosting'] as Map<String, dynamic>;
  final headers = [
    for (final rule in hosting['headers'] as List<dynamic>)
      for (final header
          in (rule as Map<String, dynamic>)['headers'] as List<dynamic>)
        (
          source: rule['source'] as String,
          key: (header as Map<String, dynamic>)['key'] as String,
          value: header['value'] as String,
        ),
  ];
  String headerValue(String key) =>
      headers.firstWhere((h) => h.key == key).value;

  List<String> cspDirective(String name) {
    final directive = headerValue('Content-Security-Policy')
        .split(';')
        .map((d) => d.trim().split(' '))
        .firstWhere((parts) => parts.first == name);
    return directive.sublist(1);
  }

  group('hosting', () {
    test('serves the combined build, with a build step before deploying', () {
      expect(hosting['public'], 'build/web');
      expect(hosting['predeploy'], contains('tool/web/build_site.sh'));
      expect(File('tool/web/build_site.sh').existsSync(), isTrue);
    });

    test('lets the page ask for location; camera stays off', () {
      final policy = headerValue('Permissions-Policy');
      expect(policy, contains('geolocation=(self)'));
      expect(policy, contains('camera=()'));
    });

    test('never lets browsers keep an old copy of the app shell', () {
      final revalidated = headers.where(
        (h) => h.key == 'Cache-Control' && h.value == 'no-cache',
      );
      expect(revalidated.map((h) => h.source), contains('/'));
      expect(
        revalidated.map((h) => h.source),
        contains('**/*.@(js|json|html|wasm)'),
      );
    });

    test('no other rule caches JavaScript, so the two cannot conflict', () {
      final longLived = headers.where(
        (h) => h.key == 'Cache-Control' && h.value != 'no-cache',
      );
      for (final rule in longLived) {
        expect(rule.source, isNot(contains('js')));
      }
    });
  });

  group('content security policy', () {
    test('allows every service the app connects to', () {
      expect(
        cspDirective('connect-src'),
        containsAll([
          "'self'",
          'https://firestore.googleapis.com',
          'https://identitytoolkit.googleapis.com',
          'https://securetoken.googleapis.com',
          'https://tiles.openfreemap.org',
          'https://tile.openstreetmap.org',
          'https://overpass-api.de',
          'https://nominatim.openstreetmap.org',
          'https://fonts.gstatic.com',
        ]),
      );
    });

    test('allows the Firebase SDK and the Flutter engine to load', () {
      expect(
        cspDirective('script-src'),
        containsAll([
          "'self'",
          "'wasm-unsafe-eval'",
          'https://www.gstatic.com',
        ]),
      );
    });

    test('forbids inline scripts, so the page must not contain any', () {
      expect(cspDirective('script-src'), isNot(contains("'unsafe-inline'")));
      final page = File('web/index.html').readAsStringSync();
      final inline = RegExp(r'<script(?![^>]*\bsrc=)[^>]*>');
      expect(inline.hasMatch(page), isFalse);
    });

    test('allows the workers behind the PWA and the local database', () {
      expect(cspDirective('worker-src'), contains("'self'"));
    });
  });

  group('web shell', () {
    test('the bootstrap registers the app service worker', () {
      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, contains("serviceWorker.register('sw.js')"));
      expect(File('web/sw.js').existsSync(), isTrue);
    });

    test('loads the Firebase SDK itself, as the CSP forbids the inline '
        'script FlutterFire would otherwise add', () {
      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      for (final global in [
        'firebase_core',
        'firebase_auth',
        'firebase_firestore',
        'firebase_storage',
      ]) {
        expect(bootstrap, contains(global));
      }
    });

    test('loads the Firebase SDK version FlutterFire expects', () {
      final config =
          jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
              as Map<String, dynamic>;
      final package = (config['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == 'firebase_core_web');
      final source = File.fromUri(
        Uri.parse('${package['rootUri']}/lib/src/firebase_sdk_version.dart'),
      ).readAsStringSync();
      final version = RegExp(
        r"supportedFirebaseJsSdkVersion = '([^']+)'",
      ).firstMatch(source)!.group(1);

      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, contains("const FIREBASE_SDK = '$version'"));
    });

    test('offline, only the map falls back to the app shell', () {
      final worker = File('web/sw.js').readAsStringSync();
      expect(worker, contains("new URL(request.url).pathname === '/'"));
    });

    test('the web has no route into reporting prices', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains("if (!kIsWeb) ...{\n            '/report':"));
    });

    test('the manifest is installable and branded', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(manifest['name'], 'Gasolinahan');
      expect(manifest['display'], 'standalone');
      expect(manifest['start_url'], '/');
      expect(manifest['description'], isNot(contains('Flutter')));

      final icons = (manifest['icons'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final sizes = icons.map((i) => i['sizes']);
      expect(sizes, containsAll(['192x192', '512x512']));
      expect(icons.where((i) => i['purpose'] == 'maskable'), isNotEmpty);
      for (final icon in icons) {
        expect(File('web/${icon['src']}').existsSync(), isTrue);
      }
    });

    test('the local database files are in the shell', () {
      expect(File('web/sqlite3.wasm').existsSync(), isTrue);
      expect(File('web/sqflite_sw.js').existsSync(), isTrue);
    });
  });

  group('website', () {
    test('the map owns the root; the old home page moved to /about', () {
      expect(File('website/public/index.html').existsSync(), isFalse);
      expect(File('website/public/about.html').existsSync(), isTrue);
    });

    test('store-listed pages keep their addresses', () {
      for (final page in ['privacy', 'terms', 'delete-account', 'support']) {
        expect(File('website/public/$page.html').existsSync(), isTrue);
      }
    });

    test('no page links to sections that used to be on the root', () {
      for (final file in Directory(
        'website/public',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.html')) continue;
        expect(
          file.readAsStringSync(),
          isNot(contains('href="/#')),
          reason: file.path,
        );
      }
    });
  });

  group('firestore rules', () {
    final rules = File('firestore.rules').readAsStringSync();

    String block(String match) {
      final start = rules.indexOf(match);
      expect(start, isNot(-1), reason: match);
      return rules.substring(start, rules.indexOf('\n    }', start));
    }

    test('guests can read the map data, one document at a time', () {
      expect(block('match /directory/{docId}'), contains('allow get: if true'));
      expect(
        block('match /stations/{stationId}'),
        contains('allow get: if true'),
      );
    });

    test('listing stations still needs an account', () {
      expect(
        block('match /stations/{stationId}'),
        contains('allow list: if isSignedIn()'),
      );
      expect(
        block('match /directory/{docId}'),
        contains('allow list: if false'),
      );
    });

    test('changing the map data still needs an account', () {
      expect(
        block('match /directory/{docId}'),
        contains('allow update: if isSignedIn() && isValidDirectoryReport()'),
      );
      expect(
        block('match /stations/{stationId}'),
        contains('allow create: if isSignedIn() && isValidStationCreate()'),
      );
      expect(
        block('match /stations/{stationId}'),
        contains('allow update: if isSignedIn() && isValidStationUpdate()'),
      );
    });

    test('every field a report writes is one the rules allow', () {
      String allowed(String function) {
        final start = rules.indexOf('function $function');
        expect(start, isNot(-1), reason: function);
        return rules.substring(start, rules.indexOf('\n    }', start));
      }

      const newStation = ReportUpload(
        reportId: 'r',
        userId: 'u',
        stationId: 's',
        stationName: 'Station',
        brand: 'Brand',
        latitude: 8.5,
        longitude: 124.6,
        regularPrice: 60,
        premiumPrice: 70,
        dieselPrice: 55,
        productPrices: {'XCS': 60},
      );
      final update = directoryPriceUpdate(
        stationId: 's',
        stationExists: false,
        regularPrice: 60,
        premiumPrice: 70,
        dieselPrice: 55,
        productPrices: const {'XCS': 60},
        name: 'Station',
        brand: 'Brand',
        latitude: 8.5,
        longitude: 124.6,
        lastUpdated: 'now',
      );
      final entry = (update['stations'] as Map<String, dynamic>)['s'] as Map;

      for (final key in newStation.stationFields(stationExists: false).keys) {
        expect(allowed('isValidStationCreate'), contains("'$key'"));
      }
      for (final key in newStation.stationFields(stationExists: true).keys) {
        expect(allowed('isValidStationUpdate'), contains("'$key'"));
      }
      for (final key in entry.keys) {
        expect(allowed('isValidNewEntry'), contains("'$key'"));
      }
      expect(update.keys, containsAll(['stations', 'lastReportedStation']));
      expect(update['lastReportedStation'], 's');
    });

    test('nothing else became public', () {
      expect(RegExp('if true').allMatches(rules).length, 2);
    });
  });
}
