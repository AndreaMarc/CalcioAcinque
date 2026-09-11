/*
 * Service worker unico dell'app: notifiche push + shell offline.
 *
 * E' separato da quello di Flutter (disattivato con --pwa-strategy=none) perche'
 * deve restare registrato in modo stabile: due service worker che si contendono
 * lo scope si disinstallano a vicenda e la subscription push muore.
 *
 * Caching: "prima la rete, poi la cache". Online si scarica sempre la versione
 * corrente (niente app stantia dopo un deploy); offline si serve l'ultima copia
 * buona e, se non c'e' nulla, una pagina che lo dice invece di uno schermo nero.
 * Le chiamate API stanno su un altro origin e non passano di qui.
 */

const APP_ICON = 'icons/Icon-192.png';
const SHELL_CACHE = 'incampo-shell-v1';
const PRECACHE = [
  './',
  'index.html',
  'offline.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'icons/brand.svg',
  APP_ICON,
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then((cache) => Promise.allSettled(PRECACHE.map((url) => cache.add(url))))
      // Entra in servizio subito, senza aspettare che si chiudano le altre schede
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k.startsWith('incampo-shell-') && k !== SHELL_CACHE).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.endsWith('/push-sw.js')) return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, 'index.html'));
    return;
  }
  event.respondWith(networkFirst(request, null));
});

async function networkFirst(request, navigationFallback) {
  const cache = await caches.open(SHELL_CACHE);
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      cache.put(request, response.clone()).catch(() => undefined);
    }
    return response;
  } catch (e) {
    const cached = await cache.match(request, { ignoreSearch: navigationFallback !== null });
    if (cached) return cached;
    if (navigationFallback) {
      const shell = await cache.match(navigationFallback);
      if (shell) return shell;
      const offline = await cache.match('offline.html');
      if (offline) return offline;
    }
    return new Response('Sei senza rete.', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
  }
}

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (e) {
    // Payload non JSON: meglio una notifica generica che nessuna notifica
    payload = { title: 'InCampo', body: event.data ? event.data.text() : '' };
  }

  const title = payload.title || 'InCampo';
  const options = {
    body: payload.body || '',
    icon: APP_ICON,
    badge: APP_ICON,
    // Stesso tag = la nuova notifica sostituisce la precedente invece di accumularsi
    tag: payload.tag || 'incampo',
    renotify: true,
    data: { url: payload.url || '/dashboard' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  // Il router dell'app usa gli hash: /#/match/12
  const route = (event.notification.data && event.notification.data.url) || '/dashboard';
  const target = new URL('#' + route, self.registration.scope).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        // App gia' aperta: la si porta in primo piano e si naviga
        if ('focus' in client) {
          client.focus();
          if ('navigate' in client) {
            return client.navigate(target).catch(() => undefined);
          }
          return undefined;
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(target);
      }
      return undefined;
    })
  );
});
