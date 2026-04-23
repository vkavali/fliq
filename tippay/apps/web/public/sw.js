// Fliq Service Worker — PWA Offline & Caching
const CACHE_NAME = 'fliq-v4';
const STATIC_ASSETS = [
  '/app/',
  '/app/index.html',
  '/app/app.js',
  '/app/styles.css',
  '/app/theme-v2.css',
  '/app/tip.html',
  '/app/tip-v5.js',
  '/app/logo-full.png',
  '/app/icon-192.png',
  '/app/icon-512.png',
  '/app/manifest.json'
];

// Install: Pre-cache static assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

// Activate: Clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// Fetch: Network-first for API, Cache-first for static assets
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // API calls: network-first (never cache API responses)
  if (url.pathname.startsWith('/api/') || url.hostname !== location.hostname) {
    event.respondWith(
      fetch(event.request).catch(() => {
        // Return offline fallback for navigation requests
        if (event.request.mode === 'navigate') {
          return caches.match('/app/index.html');
        }
        return new Response('Offline', { status: 503 });
      })
    );
    return;
  }

  // Static assets: cache-first, with network fallback
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) {
        // Return cached, but also update cache in background
        const fetchPromise = fetch(event.request).then(response => {
          if (response && response.status === 200) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(event.request, responseClone));
          }
          return response;
        }).catch(() => cached);
        return cached;
      }
      // Not in cache: fetch from network and cache
      return fetch(event.request).then(response => {
        if (response && response.status === 200) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, responseClone));
        }
        return response;
      }).catch(() => {
        if (event.request.mode === 'navigate') {
          return caches.match('/app/index.html');
        }
      });
    })
  );
});
