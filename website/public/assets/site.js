// ──────────────────────────────────────────────────────────────
//  STORE LINKS: the only place to change when the app goes live.
//  Paste each store URL between the quotes. Empty = "Coming soon".
// ──────────────────────────────────────────────────────────────
const STORE_LINKS = {
  appStore: "", // e.g. "https://apps.apple.com/ph/app/gasolinahan/id0000000000"
  googlePlay: "", // e.g. "https://play.google.com/store/apps/details?id=com.maalam.gasolinahan"
};

// Turns every "Coming soon" store button whose link is set into a real link.
// Without JavaScript the buttons simply stay "Coming soon".
const LIVE_LABELS = {
  appStore: ["Download on the", "App Store"],
  googlePlay: ["Get it on", "Google Play"],
};

for (const button of document.querySelectorAll("[data-store]")) {
  const store = button.dataset.store;
  const href = STORE_LINKS[store];
  if (!href) continue;

  const link = document.createElement("a");
  link.className = button.className;
  link.href = href;
  link.rel = "noopener";
  link.dataset.store = store;
  link.append(...button.childNodes);

  const [small, strong] = LIVE_LABELS[store];
  link.querySelector("small").textContent = small;
  link.querySelector("strong").textContent = strong;
  button.replaceWith(link);
}

// Store-note text that only makes sense before launch.
if (STORE_LINKS.appStore && STORE_LINKS.googlePlay) {
  for (const note of document.querySelectorAll("[data-prelaunch]")) {
    note.hidden = true;
  }
}
