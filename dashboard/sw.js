/* Uptime Monitor — service worker (v2 PWA shell cache).
 * Bump CACHE_VERSION whenever index.html, manifest.json, or the icons change. */
var CACHE_VERSION = 'uptime-shell-v1';
var SHELL_FILES = [
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './icon-180.png'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_VERSION).then(function (cache) {
      return cache.addAll(SHELL_FILES);
    }).then(function () {
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (key) {
        if (key !== CACHE_VERSION) return caches.delete(key);
      }));
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (event) {
  var url = new URL(event.request.url);
  // App shell: cache-first (works offline once installed).
  var isShell = SHELL_FILES.some(function (f) {
    return url.pathname.endsWith('/' + f.replace('./', ''));
  }) || url.pathname.endsWith('/index.html') || url.pathname.endsWith('/dashboard/');
  if (isShell && event.request.method === 'GET') {
    event.respondWith(
      caches.match(event.request).then(function (hit) {
        return hit || fetch(event.request);
      })
    );
    return;
  }
  // Everything else (Supabase API, CDN): network-first, no caching.
  event.respondWith(fetch(event.request));
});
