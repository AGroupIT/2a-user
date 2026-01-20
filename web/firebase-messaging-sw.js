// Firebase Messaging Service Worker for Web Push Notifications
// This file handles background push notifications when the browser is closed or in background

importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');

// Initialize Firebase with your project config
firebase.initializeApp({
  apiKey: 'AIzaSyDpIETRJbo2aMr0qELkpxZ0dacTiZrrG_0',
  appId: '1:949693718080:web:83f29ac197174e289a49a5',
  messagingSenderId: '949693718080',
  projectId: 'a-user',
  storageBucket: 'a-user.firebasestorage.app',
  authDomain: 'a-user.firebaseapp.com',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'Новое уведомление';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.messageId || 'default',
    data: payload.data || {},
    // Vibration pattern for mobile
    vibrate: [100, 50, 100],
    // Actions (optional)
    actions: [
      {
        action: 'open',
        title: 'Открыть',
      },
    ],
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click:', event);
  
  event.notification.close();

  // Get the route from notification data
  const route = event.notification.data?.route || '/';

  // Open the app or focus existing window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus();
          // Navigate to route if needed
          if (route && route !== '/') {
            client.postMessage({ type: 'NOTIFICATION_CLICK', route: route });
          }
          return;
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(route);
      }
    })
  );
});
