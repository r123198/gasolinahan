'use strict';

// Makes the app installable and lets it reopen with no connection. Always
// asks the network first, so a new deploy reaches people on their next visit;
// the cache is only the fallback. Bump the version to drop old caches.
const CACHE = 'gasolinahan-v1';

const isChromium = 'userAgentData' in self.navigator;
const canvasKit = isChromium ? 'canvaskit/chromium/' : 'canvaskit/';

const APP_SHELL = [
  '/',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin.json',
  `${canvasKit}canvaskit.js`,
  `${canvasKit}canvaskit.wasm`,
];

// The Firebase SDK loads from here, and the app can't start without it.
const CACHED_ORIGINS = new Set([self.location.origin, 'https://www.gstatic.com']);

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      // One failed file shouldn't stop the install; the rest of the shell
      // still fills in as the app runs.
      await Promise.allSettled(APP_SHELL.map((url) => cache.add(url)));
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names.filter((name) => name !== CACHE).map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response.ok) await cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    if (cached) return cached;
    // The map's address with a query string added. Other pages, like
    // /privacy, must not turn into the map when they aren't cached.
    if (new URL(request.url).pathname === '/') {
      const shell = await cache.match('/', { ignoreSearch: true });
      if (shell) return shell;
    }
    throw error;
  }
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  if (!CACHED_ORIGINS.has(new URL(request.url).origin)) return;
  event.respondWith(networkFirst(request));
});
