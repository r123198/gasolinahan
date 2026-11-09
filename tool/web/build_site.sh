#!/usr/bin/env bash
# Builds what Firebase Hosting serves: the Flutter app at the root, with the
# static pages (about, privacy, terms, support, delete-account, 404) beside it.
# `firebase deploy --only hosting` runs this first (see firebase.json).
set -euo pipefail
cd "$(dirname "$0")/../.."

# --csp and local CanvasKit keep the app within the site's security policy.
fvm flutter build web --release --csp --no-web-resources-cdn --no-wasm-dry-run

cp -R website/public/. build/web/
