const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function worker(windows = []) {
  const calls = [];
  const handlers = {};
  let receive;
  const messaging = () => ({ onBackgroundMessage: callback => { receive = callback; } });
  messaging.isSupported = () => true;
  const context = {
    URL, console,
    self: { location: { origin: 'https://app.test' },
      addEventListener: (type, callback) => { calls.push(type); handlers[type] = callback; },
      registration: { showNotification: (...args) => { calls.push(['show', ...args]); } } },
    clients: { matchAll: async () => windows, openWindow: async url => { calls.push(['open', url]); } },
    importScripts: () => calls.push('import'),
    firebase: { initializeApp() {}, messaging },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../web/firebase-messaging-sw.js'), 'utf8'), context);
  return { calls, receive: payload => receive(payload), click: async data => {
    let done;
    handlers.notificationclick({ notification: { data, close() {} }, stopImmediatePropagation() {}, waitUntil(promise) { done = promise; } });
    await done;
  } };
}

test('click registered before Firebase; notification payload does not display twice', () => {
  const sw = worker();
  assert.equal(sw.calls[0], 'notificationclick');
  sw.receive({ notification: { title: 'automatic' } });
  assert.equal(sw.calls.filter(call => Array.isArray(call) && call[0] === 'show').length, 0);
  sw.receive({ data: { title: 'data only', route: '/tracks' } });
  assert.equal(sw.calls.filter(call => Array.isArray(call) && call[0] === 'show').length, 1);
});

test('click navigates existing app via Flutter hash route and focuses it', async () => {
  const calls = [];
  const app = { url: 'https://app.test/#/home', navigate: async url => { calls.push(url); return app; }, focus: async () => calls.push('focused') };
  const sw = worker([{ url: 'https://other.test' }, app]);
  await sw.click({ FCM_MSG: { data: { route: '/invoices/12' } } });
  assert.deepEqual(calls, ['https://app.test/#/invoices/12', 'focused']);
});

test('cold click opens the app; external/protocol-relative routes stay on app origin', async () => {
  const sw = worker();
  await sw.click({ route: '/tracks/2' });
  await sw.click({ route: '//evil.test' });
  assert.deepEqual(sw.calls.filter(Array.isArray), [['open', 'https://app.test/#/tracks/2'], ['open', 'https://app.test/#/']]);
});
