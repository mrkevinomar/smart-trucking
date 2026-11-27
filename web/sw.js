/* Smart Trucking app-shell service worker.
 *
 * Flutter 3.44 ships a `flutter_service_worker.js` that only unregisters
 * itself, so this file provides the install requirement (manifest + service
 * worker) for the PWA. Strategy: precache the shell at install, then
 * cache-first for same-origin static assets and network-first for navigation.
 *
 * Per study 5.6 the cache must never hold authenticated API responses; this
 * worker only caches same-origin GET requests under its own scope and skips
 * anything under /api/.
 */
const VERSION = 'st-shell-v1';
const BASE = new URL(self.registration.scope).pathname; // e.g. "/smart-trucking/"
const SHELL = [
  '',
  'index.html',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
].map((p) => BASE + p);

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(VERSION).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))),
    ).then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith(BASE)) return;
  if (url.pathname.startsWith(BASE + 'api/')) return; // never cache API calls

  if (req.mode === 'navigate') {
    // Network first; fall back to the cached shell when offline.
    event.respondWith(
      fetch(req).catch(() => caches.match(BASE + 'index.html')),
    );
    return;
  }

  // Static assets: cache first, then network, storing a copy.
  event.respondWith(
    caches.match(req).then((hit) => {
      if (hit) return hit;
      return fetch(req).then((res) => {
        if (res.ok && res.type === 'basic') {
          const copy = res.clone();
          caches.open(VERSION).then((cache) => cache.put(req, copy));
        }
        return res;
      });
    }),
  );
});
