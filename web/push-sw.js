self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }

  const title = typeof data.title === 'string' && data.title ? data.title : 'RESET.';
  const options = {
    body: typeof data.body === 'string' ? data.body : '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: typeof data.tag === 'string' ? data.tag : 'reset-reminder',
    renotify: false,
    data: { url: typeof data.url === 'string' && data.url ? data.url : '/' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const raw = event.notification.data;
  let target = '/';
  if (raw && typeof raw === 'object' && typeof raw.url === 'string' && raw.url) {
    target = raw.url;
  } else if (typeof raw === 'string' && raw) {
    target = raw;
  }

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        for (const client of windowClients) {
          if ('focus' in client) {
            client.focus();
            return undefined;
          }
        }
        return self.clients.openWindow(target);
      }),
  );
});

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
