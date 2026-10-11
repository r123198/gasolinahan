import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

/// Which build this is, from `--flavor` (see docs/build-flavors.md).
/// dev talks to its own Firebase project, so testing never touches real
/// users' data.
enum Flavor {
  dev('DEV'),
  prod(null);

  /// Corner banner text, so a test build is never mistaken for the real one.
  final String? label;

  const Flavor(this.label);
}

/// Builds without a flavor (unit tests, tooling) count as prod. An unknown
/// name fails loudly rather than guessing which database to use.
Flavor flavorFrom(String? name) => switch (name) {
  'dev' => Flavor.dev,
  'prod' || null => Flavor.prod,
  _ => throw ArgumentError.value(name, 'flavor', 'Expected dev or prod'),
};

FirebaseOptions firebaseOptionsFor(Flavor flavor) => switch (flavor) {
  Flavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
  Flavor.prod => prod.DefaultFirebaseOptions.currentPlatform,
};
