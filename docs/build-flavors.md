# Build flavors: dev and prod

| | dev | prod |
|---|---|---|
| What it's for | Building and testing on your phone | The App Store and Google Play |
| App name | Gasolinahan Dev (with a "DEV" corner banner) | Gasolinahan |
| Android package / iOS bundle ID | `com.maalam.gasolinahan.dev` | `com.maalam.gasolinahan` |
| Firebase project | Your dev project (set up below) | `gasolinahan-e0917` |

The two have different IDs, so both can be installed on one phone. Test
accounts, reports and fill-ups made in dev never reach real users.

## Everyday commands

```sh
# Run on a connected phone (dev is the default, see pubspec.yaml)
fvm flutter run
fvm flutter run --flavor prod        # try the real thing

# Store builds: always pass --flavor prod
fvm flutter build appbundle --release --flavor prod
fvm flutter build ipa --release --flavor prod
```

A build without `--flavor` is a **dev** build. If you forget `--flavor prod`,
the store rejects the upload because the package name ends in `.dev`, so
the mistake can't reach users.

Where the output lands:

- Android: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`
- iOS: `build/ios/ipa/`

In Xcode, pick the `dev` or `prod` scheme. The old `Runner` scheme also
builds prod.

## One-time setup: the dev Firebase project

dev builds stop with "missing google-services.json" (Android) or "Missing
…/config/dev/GoogleService-Info.plist" (iOS) until this is done.

1. In the [Firebase console](https://console.firebase.google.com), add a
   project, for example `gasolinahan-dev`. The free Spark plan is fine.
   Analytics can stay off.
2. In that project:
   - **Authentication → Sign-in method:** turn on Email/Password.
   - **Firestore Database:** create a database. Pick a region near you,
     such as `asia-southeast1`.
3. From the project folder, connect it. Use the project ID the console
   shows:

   ```sh
   flutterfire configure \
     -p gasolinahan-dev \
     --platforms=android,ios \
     -o lib/firebase_options_dev.dart \
     -a com.maalam.gasolinahan.dev \
     -i com.maalam.gasolinahan.dev \
     --android-out=android/app/src/dev/google-services.json \
     --ios-out=ios/config/dev/GoogleService-Info.plist \
     -y
   ```

   This replaces the placeholder `lib/firebase_options_dev.dart` and writes
   the two config files.
4. Give dev the same security rules and indexes as production:

   ```sh
   firebase deploy --only firestore --project gasolinahan-dev
   ```

   Repeat this whenever `firestore.rules` or `firestore.indexes.json`
   changes. (`firebase deploy` without `--project` targets production.)
5. Check it works: run `fvm flutter run`, sign up, and confirm the new user
   appears in the **dev** project's Authentication tab, not production's.

To seed dev with test data, the debug-only `/seed` screen works as before.
It writes to whichever project the running flavor uses.

## Storage (profile photos)

Profile photos use Cloud Storage. Firebase projects created since late
2024 only get a Storage bucket on the pay-as-you-go **Blaze** plan. Blaze
needs a billing card, but a small app stays inside its free usage. The
production project currently appears to have no bucket, so profile photo
upload fails there. Either:

- upgrade production (and dev, if you want photos there) to Blaze and
  create the bucket, or
- hide the Profile photo option until then.

Account deletion copes with a missing bucket either way.

## How it's wired

- **Dart:** `lib/main.dart` reads the flavor (`appFlavor`) and
  `lib/app_flavor.dart` picks `firebase_options_dev.dart` or
  `firebase_options_prod.dart`. An unknown flavor fails at startup rather
  than guessing a database.
- **Android:** `productFlavors` in `android/app/build.gradle.kts`. Each
  flavor's `google-services.json` is in `android/app/src/<flavor>/`. Release
  signing (key.properties) applies to both.
- **iOS:**
  - Build configurations `Debug-dev`, `Release-dev`, `Profile-dev` and the
    `-prod` equivalents, with `dev` and `prod` schemes.
  - Each configuration sets `PRODUCT_BUNDLE_IDENTIFIER`,
    `APP_DISPLAY_NAME` and `FLAVOR_NAME`.
  - A **Copy Firebase config** build phase copies
    `ios/config/<flavor>/GoogleService-Info.plist` into the app.
  - The Podfile maps each new configuration to debug or release.
- **Re-running flutterfire for prod:** `firebase.json` already points at
  `lib/firebase_options_prod.dart`, `android/app/src/prod/` and
  `ios/config/prod/`.
