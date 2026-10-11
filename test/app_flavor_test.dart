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
