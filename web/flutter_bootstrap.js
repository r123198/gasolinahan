{{flutter_js}}
{{flutter_build_config}}

window.addEventListener(
  'flutter-first-frame',
  () => document.getElementById('splash')?.remove(),
  { once: true },
);

// Flutter's own service worker is deprecated and only unregisters itself, so
// the app registers its own (web/sw.js).
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch((error) => {
      console.warn('Offline support unavailable:', error);
    });
  });
}

// FlutterFire normally adds the Firebase SDK with an inline <script>, which the
// site's Content-Security-Policy refuses. It skips that when these globals
// already exist, so they are loaded here first. The version must match
// firebase_core_web; test/web/hosting_config_test.dart checks it.
const FIREBASE_SDK = '11.9.1';
const FIREBASE_MODULES = {
  firebase_core: 'app',
  firebase_auth: 'auth',
  firebase_firestore: 'firestore',
  firebase_storage: 'storage',
};

Promise.all(
  Object.entries(FIREBASE_MODULES).map(async ([name, module]) => {
    window[name] = await import(
      `https://www.gstatic.com/firebasejs/${FIREBASE_SDK}/firebase-${module}.js`
    );
  }),
)
  .then(() => _flutter.loader.load())
  .catch((error) => {
    console.error('Could not start Gasolinahan:', error);
    const message = document.createElement('p');
    message.textContent =
      "Couldn't load Gasolinahan. Check your connection and reload the page.";
    message.style.cssText = 'margin:3rem 1.5rem;font:1rem system-ui;text-align:center';
    document.getElementById('splash')?.remove();
    document.body.append(message);
  });
