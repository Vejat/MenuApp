self.addEventListener('push', event => {
  const data = event.data ? event.data.json() : {};
  event.waitUntil(self.registration.showNotification(data.title || 'MenuApp', {
    body: data.body || 'Tienes una actualización.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.tag || 'menuapp-update',
    vibrate: [250, 120, 250],
    data: { url: data.url || '/' }
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = new URL(event.notification.data.url || '/', self.location.origin).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windows => {
    for (const client of windows) if (client.url.startsWith(self.location.origin) && 'focus' in client) return client.focus();
    return self.clients.openWindow(target);
  }));
});
