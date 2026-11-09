// Runs firestore.rules against the local emulator; nothing here touches a real
// database. reportBatch() must keep matching lib/services/report_writer.dart:
// a report the rules reject never reaches the map.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const known = 'known1';
const other = 'other1';
const knownStation = {
  name: 'Shell Lapasan',
  brand: 'Shell',
  latitude: 8.48,
  longitude: 124.66,
  regularPrice: 60,
};
const entry = (name) => ({ n: name, b: 'Shell', la: 8.48, lo: 124.66, r: 60 });

let env;
let reportCounter = 0;

const signedIn = () => env.authenticatedContext('driver').firestore();
const guest = () => env.unauthenticatedContext().firestore();
const directory = (db) => doc(db, 'directory', 'stations');
const station = (db, id) => doc(db, 'stations', id);

/** The whole batch ReportWriter.write sends. */
function reportBatch(
  db,
  { id = known, exists = true, prices = { r: 62.5 }, describe: place = {} } = {},
) {
  const reportId = `report_${++reportCounter}`;
  const stationFields = {
    ...(prices.r && { regularPrice: prices.r }),
    ...(prices.p && { premiumPrice: prices.p }),
    ...(prices.d && { dieselPrice: prices.d }),
    ...(prices.pp && { productPrices: prices.pp }),
    ...(!exists && {
      ...(place.n && { name: place.n }),
      ...(place.b && { brand: place.b }),
      ...(place.la && { latitude: place.la }),
      ...(place.lo && { longitude: place.lo }),
    }),
  };
  const directoryEntry = {
    ...(prices.r && { r: prices.r }),
    ...(prices.p && { p: prices.p }),
    ...(prices.d && { d: prices.d }),
    ...(prices.pp && { pp: prices.pp }),
    u: serverTimestamp(),
    ...(!exists && place),
  };
  return writeBatch(db)
    .set(doc(db, 'reports', reportId), {
      userId: 'driver',
      stationId: id,
      reportedRegularPrice: prices.r ?? 0,
      reportedPremiumPrice: prices.p ?? 0,
      reportedDieselPrice: prices.d ?? 0,
      reportedProductPrices: prices.pp ?? {},
      pointsAwarded: 3,
      pointsReason: 'Price report +3',
      status: 'accepted',
      timestamp: serverTimestamp(),
    })
    .set(
      station(db, id),
      { ...stationFields, lastUpdated: serverTimestamp() },
      { merge: true },
    )
    .set(
      directory(db),
      { lastReportedStation: id, stations: { [id]: directoryEntry } },
      { merge: true },
    )
    .set(
      doc(db, 'users', 'driver'),
      {
        reportsCount: increment(1),
        points: increment(3),
        lifetimePoints: increment(3),
      },
      { merge: true },
    )
    .set(doc(db, 'users', 'driver', 'points_ledger', `report_${reportId}`), {
      points: 3,
      reason: 'Price report +3',
      source: `report:${reportId}`,
      at: serverTimestamp(),
    });
}

const directoryWrite = (db, data) => setDoc(directory(db), data, { merge: true });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-gasolinahan',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(station(db, known), knownStation);
    await setDoc(station(db, other), knownStation);
    await setDoc(directory(db), {
      count: 2,
      updatedAt: new Date(),
      stations: { [known]: entry('Shell Lapasan'), [other]: entry('Other') },
    });
  });
});

describe('reports the phone app sends', () => {
  test('a report on a known station', () =>
    assertSucceeds(reportBatch(signedIn()).commit()));

  test('every grade and product at once', () =>
    assertSucceeds(
      reportBatch(signedIn(), {
        prices: {
          r: 60.5,
          p: 70,
          d: 55.25,
          pp: { 'V-Power Gasoline': 71.1, 'V-Power Diesel': 58 },
        },
      }).commit(),
    ));

  test('the lowest and highest allowed prices', async () => {
    await assertSucceeds(
      reportBatch(signedIn(), { prices: { r: 30 } }).commit(),
    );
    await assertSucceeds(
      reportBatch(signedIn(), { prices: { r: 150 } }).commit(),
    );
  });

  test('two reports in a row on the same station', async () => {
    await assertSucceeds(reportBatch(signedIn()).commit());
    await assertSucceeds(
      reportBatch(signedIn(), { prices: { r: 63 } }).commit(),
    );
  });

  test('reports on different stations, one after the other', async () => {
    await assertSucceeds(reportBatch(signedIn()).commit());
    await assertSucceeds(reportBatch(signedIn(), { id: other }).commit());
  });

  test('a report that adds a new station', () =>
    assertSucceeds(
      reportBatch(signedIn(), {
        id: 'new_station',
        exists: false,
        describe: { n: 'New Fuel', b: 'Petron', la: 8.5, lo: 124.6 },
      }).commit(),
    ));

  test('a new station with no brand or position', () =>
    assertSucceeds(
      reportBatch(signedIn(), {
        id: 'typed_name',
        exists: false,
        describe: { n: 'Typed Name' },
      }).commit(),
    ));

  test('a station lookup that failed: priced, but not described', () =>
    assertSucceeds(
      reportBatch(signedIn(), { id: 'lookup_failed', exists: true }).commit(),
    ));

  test('the first report on a directory with no marker yet', async () => {
    await assertSucceeds(reportBatch(signedIn()).commit());
    const snapshot = await getDoc(directory(guest()));
    if (snapshot.data().lastReportedStation !== known) {
      throw new Error('the marker was not stored');
    }
  });
});

describe('stations: what a signed-in account cannot do', () => {
  const write = (data) =>
    setDoc(
      station(signedIn(), known),
      { lastUpdated: serverTimestamp(), ...data },
      { merge: true },
    );

  for (const [label, data] of [
    ['rename', { name: 'Hacked' }],
    ['rebrand', { brand: 'Hacked' }],
    ['move', { latitude: 1 }],
    ['add another field', { notes: 'Hacked' }],
    ['price too low', { regularPrice: 29.99 }],
    ['price too high', { dieselPrice: 150.01 }],
    ['price as text', { premiumPrice: '60' }],
    ['products as text', { productPrices: 'Hacked' }],
    ['fake a date', { lastUpdated: new Date(0) }],
  ]) {
    test(label, () => assertFails(write(data)));
  }

  test('too many products', () =>
    assertFails(
      write({
        productPrices: Object.fromEntries(
          Array.from({ length: 41 }, (_, i) => [`product ${i}`, 60]),
        ),
      }),
    ));

  test('change a price without updating the date', () =>
    assertFails(
      updateDoc(station(signedIn(), known), { regularPrice: 61 }),
    ));

  test('remove a price', () =>
    assertFails(
      updateDoc(station(signedIn(), known), {
        regularPrice: deleteField(),
        lastUpdated: serverTimestamp(),
      }),
    ));

  test('delete', () => assertFails(deleteDoc(station(signedIn(), known))));

  for (const [label, data] of [
    ['unknown field', { notes: 'Hacked' }],
    ['outside the Philippines', { latitude: 51.5, longitude: 0.1 }],
    ['price too high', { regularPrice: 500 }],
    ['oversized name', { name: 'x'.repeat(201) }],
    ['name as a number', { name: 7 }],
  ]) {
    test(`create: ${label}`, () =>
      assertFails(
        setDoc(station(signedIn(), 'bogus'), {
          lastUpdated: serverTimestamp(),
          ...data,
        }),
      ));
  }
});

describe('directory: what a signed-in account cannot do', () => {
  const report = (id, fields) => ({
    lastReportedStation: id,
    stations: { [id]: { u: serverTimestamp(), ...fields } },
  });

  for (const [label, fields] of [
    ['rename', { n: 'Hacked' }],
    ['rebrand', { b: 'Hacked' }],
    ['move', { la: 1 }],
    ['add another field', { x: 1 }],
    ['price too low', { r: 1 }],
    ['price too high', { d: 999 }],
    ['price as text', { p: '60' }],
    ['products as text', { pp: 'Hacked' }],
    ['fake a date', { u: new Date(0) }],
  ]) {
    test(label, () => assertFails(directoryWrite(signedIn(), report(known, fields))));
  }

  test('write under a station other than the one it names', () =>
    assertFails(
      directoryWrite(signedIn(), {
        lastReportedStation: other,
        stations: { [known]: { u: serverTimestamp(), r: 61 } },
      }),
    ));

  test('change two stations at once', () =>
    assertFails(
      directoryWrite(signedIn(), {
        lastReportedStation: known,
        stations: {
          [known]: { u: serverTimestamp(), r: 61 },
          [other]: { u: serverTimestamp(), r: 61 },
        },
      }),
    ));

  test('leave out the station it changes', () =>
    assertFails(
      directoryWrite(signedIn(), {
        stations: { [known]: { u: serverTimestamp(), r: 61 } },
      }),
    ));

  test('change the fields around the stations', () =>
    assertFails(directoryWrite(signedIn(), { ...report(known, { r: 61 }), count: 0 })));

  test('remove a station', () =>
    assertFails(
      updateDoc(directory(signedIn()), {
        lastReportedStation: known,
        [`stations.${known}`]: deleteField(),
      }),
    ));

  test('remove a price', () =>
    assertFails(
      updateDoc(directory(signedIn()), {
        lastReportedStation: known,
        [`stations.${known}.r`]: deleteField(),
        [`stations.${known}.u`]: serverTimestamp(),
      }),
    ));

  test('wipe every station', () =>
    assertFails(
      setDoc(directory(signedIn()), { lastReportedStation: known, stations: {} }),
    ));

  test('delete the document', () =>
    assertFails(deleteDoc(directory(signedIn()))));

  for (const [label, fields] of [
    ['unknown field', { n: 'New', x: 1 }],
    ['outside the Philippines', { n: 'New', la: 51.5, lo: 0.1 }],
    ['price too high', { n: 'New', r: 500 }],
    ['oversized name', { n: 'x'.repeat(201) }],
  ]) {
    test(`new station: ${label}`, () =>
      assertFails(directoryWrite(signedIn(), report('bogus', fields))));
  }

  test('new station: oversized id', () => {
    const id = 'x'.repeat(201);
    return assertFails(directoryWrite(signedIn(), report(id, { n: 'New' })));
  });

  test('new station: the directory is full', async () => {
    await env.withSecurityRulesDisabled((context) =>
      setDoc(directory(context.firestore()), {
        stations: Object.fromEntries(
          Array.from({ length: 2000 }, (_, i) => [`s${i}`, { n: 'S' }]),
        ),
      }),
    );
    await assertFails(
      directoryWrite(signedIn(), report('bogus', { n: 'New' })),
    );
    await assertSucceeds(
      directoryWrite(signedIn(), report('s1', { r: 61 })),
    );
  });
});

describe('guests', () => {
  test('can read the map data', async () => {
    await assertSucceeds(getDoc(directory(guest())));
    await assertSucceeds(getDoc(station(guest(), known)));
  });

  test('cannot write it', async () => {
    await assertFails(reportBatch(guest()).commit());
    await assertFails(
      directoryWrite(guest(), {
        lastReportedStation: known,
        stations: { [known]: { u: serverTimestamp(), r: 61 } },
      }),
    );
    await assertFails(
      setDoc(
        station(guest(), known),
        { regularPrice: 61, lastUpdated: serverTimestamp() },
        { merge: true },
      ),
    );
  });
});
