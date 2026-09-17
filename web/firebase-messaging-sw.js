// Register before Firebase so the SDK cannot intercept custom clicks.
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  const data = event.notification.data || {};
  const pushData = data.FCM_MSG?.data || data;
  const route = typeof pushData.route === 'string' &&
    pushData.route.startsWith('/') && !pushData.route.startsWith('//')
      ? pushData.route : '/';
  // Flutter uses its default hash URL strategy.
  const target = new URL('/#' + route, self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    const app = windows.find((client) => new URL(client.url).origin === self.location.origin);
    if (app) {
      const navigated = await app.navigate(target);
      return (navigated || app).focus();
    }
    return clients.openWindow(target);
  })());
});

importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');
firebase.initializeApp({
  apiKey: 'AIzaSyDpIETRJbo2aMr0qELkpxZ0dacTiZrrG_0',
  appId: '1:949693718080:web:83f29ac197174e289a49a5',
  messagingSenderId: '949693718080',
  projectId: 'a-user',
  storageBucket: 'a-user.firebasestorage.app',
  authDomain: 'a-user.firebaseapp.com',
});

try {
  const supported = typeof firebase.messaging.isSupported !== 'function' ||
    firebase.messaging.isSupported();
  if (supported) {
    firebase.messaging().onBackgroundMessage((payload) => {
      // FCM already displays notification payloads. Do not display them twice.
      if (payload.notification) return;
      return self.registration.showNotification(payload.data?.title || 'Новое уведомление', {
        body: payload.data?.body || '',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: payload.messageId || 'default',
        data: payload.data || {},
      });
    });
  }
} catch (error) {
  console.warn('[push] Service worker initialization unavailable:', error);
}
