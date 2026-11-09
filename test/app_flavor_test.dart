import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/app_flavor.dart';
import 'package:gasolinahan/firebase_options_prod.dart' as prod;

void main() {
  group('flavorFrom', () {
    test('reads the --flavor names', () {
      expect(flavorFrom('dev'), Flavor.dev);
      expect(flavorFrom('prod'), Flavor.prod);
    });

    test('treats a build without a flavor (tests, tools) as prod', () {
      expect(flavorFrom(null), Flavor.prod);
    });

    test('rejects an unknown flavor instead of guessing a database', () {
      expect(() => flavorFrom('staging'), throwsArgumentError);
    });
  });

  group('flavorForBuild', () {
    test('the web has only one Firebase app, so it is always prod', () {
      expect(flavorForBuild('dev', isWeb: true), Flavor.prod);
      expect(flavorForBuild(null, isWeb: true), Flavor.prod);
    });

    test('the phone apps follow --flavor', () {
      expect(flavorForBuild('dev', isWeb: false), Flavor.dev);
      expect(flavorForBuild('prod', isWeb: false), Flavor.prod);
    });
  });

  test('prod uses the production Firebase project', () {
    expect(
      firebaseOptionsFor(Flavor.prod).projectId,
      prod.DefaultFirebaseOptions.currentPlatform.projectId,
    );
    expect(firebaseOptionsFor(Flavor.prod).projectId, 'gasolinahan-e0917');
  });

  test('only dev builds are labelled for testers', () {
    expect(Flavor.dev.label, 'DEV');
    expect(Flavor.prod.label, isNull);
  });
}
