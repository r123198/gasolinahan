#!/usr/bin/env node
// Imports gas stations from the Google Places export into Firestore:
//
//   stations/{placeId}     one document per station with everything we
//                          know (hours, phone, amenities, …); price reports
//                          keep merging prices into these.
//   directory/stations     ONE document holding a compact entry for every
//                          station, so the app paints the whole map with a
//                          single read. Same shape as
//                          lib/models/station_directory.dart.
//
// Usage (from the project root):
//   node tool/stations/import_stations.mjs --dry-run
//   node tool/stations/import_stations.mjs --key path/to/serviceAccount.json
//   node tool/stations/import_stations.mjs --cli-login        # see README
//
// Options:
//   --input <file>     default gas_stations_northern_mindanao.json
//   --project <id>     default gasolinahan-e0917
//   --dry-run          transform only; writes a preview, touches nothing
//   --key <file>       service-account JSON (or GOOGLE_APPLICATION_CREDENTIALS)
//   --cli-login        reuse the Firebase CLI's login on this machine
//   --check            sign in and read the directory document, write nothing

import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const args = parseArgs(process.argv.slice(2));
const inputPath = resolve(args.input ?? 'gas_stations_northern_mindanao.json');
const projectId = args.project ?? 'gasolinahan-e0917';

const INDEPENDENT = 'Independent / other';
const BATCH_SIZE = 400;

// Brands we have a logo for in assets/images/brand_marks. Others keep
// their name and get the initials fallback in the app.
const KNOWN_BRANDS = new Set([
  'Shell', 'Petron', 'Caltex', 'Seaoil', 'Phoenix', 'Unioil', 'Total',
  'Jetti', 'PTT', 'Cleanfuel', 'Flying V', 'Blu Energy', 'Velox',
  'RM C Petrol', 'Mobil', 'Petronas', 'Aiji', 'Apex', 'Eco Oil',
  'Insular Oil', 'Fuel Master', 'TecFuel', 'Quantum',
]);

async function main() {
  const raw = JSON.parse(readFileSync(inputPath, 'utf8'));
  const { stations, skipped, stats } = transform(raw.stations ?? []);

  console.log(`Read ${raw.stations?.length ?? 0} stations from ${inputPath}`);
  console.log(`Importing ${stations.length}, skipping ${skipped.length}`);
  for (const s of skipped) console.log(`  skip ${s.id}  ${s.name}: ${s.why}`);
  console.log('Brands:', stats.brands);
  console.log('Brands without a logo yet:', stats.unknownBrands);
  console.log('Amenities listed:', stats.amenities);

  writeSamples(stations);
  if (args['dry-run']) {
    console.log('\nDry run: nothing written to Firestore.');
    return;
  }

  const db = await connect();
  if (args.check) {
    const snap = await db.collection('directory').doc('stations').get();
    const count = snap.exists ? Object.keys(snap.data().stations ?? {}).length : 0;
    console.log(
      `\nSigned in to ${projectId}. directory/stations ` +
        (snap.exists ? `exists with ${count} entries.` : 'does not exist yet.'),
    );
    return;
  }
  await writeStations(db, stations);
  await writeDirectory(db, stations);
  console.log(`\nDone: ${stations.length} stations in project ${projectId}.`);
}

// ── Transform ────────────────────────────────────────────────────────

function transform(rows) {
  const stations = [];
  const skipped = [];
  const brands = {};
  const unknownBrands = {};
  const amenities = {};

  for (const r of rows) {
    if (r.status === 'permanently_closed') {
      skipped.push({ id: r.id, name: r.name, why: 'permanently closed' });
      continue;
    }
    if (!(Number.isFinite(r.latitude) && Number.isFinite(r.longitude))) {
      skipped.push({ id: r.id, name: r.name, why: 'no coordinates' });
      continue;
    }
    const brand = r.brand === INDEPENDENT ? '' : (r.brand ?? '').trim();
    if (brand) {
      brands[brand] = (brands[brand] ?? 0) + 1;
      if (!KNOWN_BRANDS.has(brand)) {
        unknownBrands[brand] = (unknownBrands[brand] ?? 0) + 1;
      }
    }
    const am = amenitiesOf(r);
    for (const [k, v] of Object.entries(am)) {
      amenities[k] ??= { yes: 0, no: 0 };
      amenities[k][v ? 'yes' : 'no']++;
    }
    const nearbyStore = r.amenities?.convenience_store_nearby?.name ?? '';
    const full = {
      name: r.name,
      brand,
      address: r.address ?? '',
      city: r.city ?? '',
      area: r.search_area ?? '',
      latitude: r.latitude,
      longitude: r.longitude,
      amenities: am,
      ...(nearbyStore && { nearbyStore }),
      ...(r.opening_hours && { openingHours: r.opening_hours }),
      ...(r.phone && { phone: r.phone }),
      ...(r.website && { website: r.website }),
      ...(r.google_maps_url && { mapsUrl: r.google_maps_url }),
      ...(r.rating != null && { rating: r.rating }),
      ...(r.review_count > 0 && { reviewCount: r.review_count }),
      ...(r.status !== 'operational' && { status: r.status }),
      lowConfidence: (r.flags ?? []).some((f) => f.startsWith('low_confidence')),
      source: 'google_places',
      sourceId: r.id,
    };
    stations.push({ id: r.id, full, entry: directoryEntry(full) });
  }
  return { stations, skipped, stats: { brands, unknownBrands, amenities } };
}

/// Only values the source actually lists; null in the export means
/// "not listed", which must not become "no".
function amenitiesOf(r) {
  const a = r.amenities ?? {};
  const sv = r.services ?? {};
  const pay = r.payments ?? {};
  const out = {};
  const put = (key, value) => {
    if (typeof value === 'boolean') out[key] = value;
  };
  put('restroom', a.restroom);
  put('accessibleRestroom', a.wheelchair_accessible_restroom);
  put('convenienceStore', a.convenience_store);
  put('airPump', a.air_pump);
  put('atm', a.atm);
  put('carWash', sv.car_wash);
  put('oilChange', sv.oil_change);
  const cards = [pay.credit_cards, pay.debit_cards, pay.nfc_mobile];
  if (cards.some((c) => c === true)) out.cardsAccepted = true;
  else if (cards.some((c) => c === false)) out.cardsAccepted = false;
  if (r.open_24_hours === true) out.open24Hours = true;
  else if (r.opening_hours) out.open24Hours = false;
  return out;
}

const AMENITY_SHORT = {
  restroom: 'rr',
  accessibleRestroom: 'wr',
  convenienceStore: 'cs',
  airPump: 'ap',
  atm: 'atm',
  carWash: 'cw',
  oilChange: 'oc',
  cardsAccepted: 'cc',
  open24Hours: 'h24',
};

/// Compact entry for the directory document; keys documented in
/// lib/models/station_directory.dart.
function directoryEntry(s) {
  const am = {};
  for (const [k, v] of Object.entries(s.amenities)) am[AMENITY_SHORT[k]] = v ? 1 : 0;
  return {
    n: s.name,
    b: s.brand,
    ...(s.city && { c: s.city }),
    ...(s.address && { a: s.address }),
    la: s.latitude,
    lo: s.longitude,
    ...(Object.keys(am).length && { am }),
    ...(s.rating != null && { rt: s.rating }),
    ...(s.reviewCount && { rv: s.reviewCount }),
    ...(s.status && { st: s.status }),
    ...(s.nearbyStore && { ns: s.nearbyStore }),
  };
}

// ── Output ───────────────────────────────────────────────────────────

/// A small fixture the Dart tests decode, so the app and this script
/// can't drift apart, plus a full preview for eyeballing.
function writeSamples(stations) {
  const outDir = join(here, 'out');
  mkdirSync(outDir, { recursive: true });
  const preview = {
    stations: Object.fromEntries(stations.map((s) => [s.id, s.full])),
    directory: Object.fromEntries(stations.map((s) => [s.id, s.entry])),
  };
  writeFileSync(join(outDir, 'preview.json'), JSON.stringify(preview, null, 1));
  const sample = Object.fromEntries(
    stations.slice(0, 6).map((s) => [s.id, s.entry]),
  );
  writeFileSync(
    join(here, 'sample_directory.json'),
    JSON.stringify({ stations: sample }, null, 1) + '\n',
  );
  console.log(`Preview: ${join(outDir, 'preview.json')}`);
}

// ── Firestore ────────────────────────────────────────────────────────

async function connect() {
  const admin = await import('firebase-admin');
  const credential = await pickCredential(admin.default);
  admin.default.initializeApp({ credential, projectId });
  return admin.default.firestore();
}

async function pickCredential(admin) {
  const keyPath = args.key ?? process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath && !args['cli-login']) {
    const key = JSON.parse(readFileSync(resolve(keyPath), 'utf8'));
    return key.type === 'service_account'
      ? admin.credential.cert(key)
      : admin.credential.applicationDefault();
  }
  if (args['cli-login']) {
    // The Firebase CLI keeps a refresh token for its public OAuth client.
    // Firestore's client only takes certificates or Application Default
    // Credentials, so the token is handed over as an ADC "authorized_user"
    // file (the same shape gcloud writes), kept only while this runs.
    const cfg = JSON.parse(
      readFileSync(join(homedir(), '.config/configstore/firebase-tools.json'), 'utf8'),
    );
    const refresh = cfg.tokens?.refresh_token;
    if (!refresh) throw new Error('Not logged in: run `firebase login` first.');
    const adcPath = join(tmpdir(), `gasolinahan-adc-${process.pid}.json`);
    writeFileSync(
      adcPath,
      JSON.stringify({
        type: 'authorized_user',
        client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
        client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
        refresh_token: refresh,
        quota_project_id: projectId,
      }),
      { mode: 0o600 },
    );
    process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
    process.env.GOOGLE_CLOUD_PROJECT = projectId;
    const cleanup = () => rmSync(adcPath, { force: true });
    process.on('exit', cleanup);
    process.on('SIGINT', () => { cleanup(); process.exit(130); });
    return admin.credential.applicationDefault();
  }
  throw new Error(
    'No credentials. Pass --key <serviceAccount.json>, set ' +
      'GOOGLE_APPLICATION_CREDENTIALS, or pass --cli-login.',
  );
}

async function writeStations(db, stations) {
  const { FieldValue } = await import('firebase-admin/firestore');
  for (let i = 0; i < stations.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const s of stations.slice(i, i + BATCH_SIZE)) {
      // merge: a station already holding reported prices keeps them.
      batch.set(
        db.collection('stations').doc(s.id),
        { ...s.full, importedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
    await batch.commit();
    console.log(`  stations ${Math.min(i + BATCH_SIZE, stations.length)}/${stations.length}`);
  }
}

async function writeDirectory(db, stations) {
  const { FieldValue } = await import('firebase-admin/firestore');
  const entries = Object.fromEntries(stations.map((s) => [s.id, s.entry]));
  // merge: entries only known from price reports stay, and reported
  // prices on imported stations are kept (fields not in the entry are
  // untouched).
  await db.collection('directory').doc('stations').set(
    {
      stations: entries,
      importedCount: stations.length,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log('  directory/stations written');
}

// ── Args ─────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      out[key] = next;
      i++;
    } else {
      out[key] = true;
    }
  }
  return out;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
