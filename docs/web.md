# The website and web app

The site at https://gasolinahan-e0917.web.app is the Flutter app, built for
the web and installable as a PWA. Its landing page is the price map, open to
anyone and **read-only**: nobody can report prices from the web, signed in or
not. The Tracker and Account tabs need an account. The phone apps are unchanged:
they still ask for sign-in first and are where prices are reported.

## Deploying

```sh
# Rules first: the map can't load for guests until they are live.
firebase deploy --only firestore:rules

# Builds the site (tool/web/build_site.sh), then uploads it.
firebase deploy --only hosting
```

`firebase deploy` without `--project` targets production. To build without
deploying, run `tool/web/build_site.sh`; the output is in `build/web/`.

To try it locally:

```sh
fvm flutter run -d chrome
```

**This uses the production database.** Only production has a Firebase web app,
so the web build is always prod, whatever `--flavor` says. Signing in or logging
a fill-up from Chrome writes real data.

## Protecting the map data

The website has no way to change prices, but anyone can make an account and
call the database directly, so `firestore.rules` checks every write to
`stations` and `directory/stations`:

- Prices must be numbers from ₱30 to ₱150.
- A report can't rename, rebrand, move or remove an existing station.
- One write changes one directory entry, and must name it in
  `lastReportedStation`.
- A station added by a report must be in the Philippines, and the directory
  stops taking new stations at 2,000.

The rules can't catch a believable wrong price, and can't check the prices
inside a products map. Correct bad data in the Firebase console. If abuse
becomes a real problem, the next step is sending reports through Cloud Functions
(Blaze plan). The import in `tool/stations` uses an admin login, so these rules
don't apply to it.

Phone builds from before `lastReportedStation` can't send reports once these
rules are live, so release the app update first.

To test the rules (needs Java 21 or newer; nothing touches a real database):

```sh
cd tool/rules_test
npm install
npm test
```

If `ReportWriter` writes a new field, add it to the rules and to
`reportBatch()` in `tool/rules_test/rules.test.mjs`.

## What's where

| Path | What it is |
|---|---|
| `web/` | The Flutter page shell, PWA manifest, icons and service worker (`sw.js`) |
| `website/public/` | Static pages copied in beside the app: `/about` (the old home page), `/privacy`, `/terms`, `/support`, `/delete-account`, `/404` |
| `lib/models/app_access.dart` | Who can open what, on the web and on the phones |
| `lib/services/database_setup*.dart` | Runs the app's SQLite database in the browser |
| `firebase.json` | Hosting, including the Content-Security-Policy |

Store listings link to `/privacy`, `/terms`, `/support` and `/delete-account`,
so keep those addresses.

## How the web differs from the phones

| | Phones | Web |
|---|---|---|
| Opens on | Sign in, then Tracker | The map, with or without an account |
| Report a price | Camera and OCR | Not available: the map is read-only |
| Odometer | Scan or type | Type only |
| Trips and fill-up nudges | Automatic | None: browsers can't run in the background |
| Fill-up photos | Saved on the phone | Not shown: photos never leave the phone |
| Local data | SQLite | SQLite in IndexedDB, for this browser only |
| Location prompt | On open | Only after tapping my-location |

## When you change things

- **Calling a new outside service:** add its host to `connect-src` in
  `firebase.json`, or browsers will block it.
  `test/web/hosting_config_test.dart` checks the current list.
- **Upgrading `sqflite_common_ffi_web`:** version 1.1+ needs `sqlite3` 3.x,
  whose native build hooks would change the phone builds, so it is pinned at
  1.0.2. After any upgrade, run `fvm dart run sqflite_common_ffi_web:setup` to
  refresh `web/sqlite3.wasm` and `web/sqflite_sw.js`.
- **Upgrading Firebase packages:** the site's security policy blocks the inline
  script FlutterFire uses to load the Firebase JS SDK, so
  `web/flutter_bootstrap.js` loads it instead. If `firebase_core_web` wants a new
  SDK version, or a new Firebase package is added, update `FIREBASE_SDK` and
  `FIREBASE_MODULES` there. A test fails if the version no longer matches.
- **Old caches:** the service worker asks the network first, so deploys reach
  people on their next visit. Bump `CACHE` in `web/sw.js` only to clear what is
  already stored.

## Offline

An installed app reopens without a connection, but station prices come live from
Firestore, so the map shows its error message until the connection returns.
