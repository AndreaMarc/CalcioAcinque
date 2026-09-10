/*
 * Service worker dedicato alle notifiche push.
 *
 * E' separato da quello di Flutter (disattivato con --pwa-strategy=none) perche'
 * deve restare registrato in modo stabile: due service worker che si contendono
 * lo scope si disinstallano a vicenda e la subscription push muore.
 *
 * Non fa caching: serve solo a ricevere le push e ad aprire l'app al tap.
 */

const APP_ICON = 'icons/Icon-192.png';

self.addEventListener('install', (event) => {
  // Entra in servizio subito, senza aspettare che si chiudano le altre schede
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

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
