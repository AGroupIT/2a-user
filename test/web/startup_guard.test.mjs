import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../../web/index.html', import.meta.url), 'utf8');
const guard = html.match(/<script id="web-startup-guard">([\s\S]*?)<\/script>/)[1];
const bootstrap = readFileSync(new URL('../../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

function fixture(base = 'https://cabinet.synthetic.test/') {
  let time = 0, timerID = 0, reloads = 0, config;
  const timers = new Map(), listeners = new Map();
  const nodes = Object.fromEntries(['flutter-splash', 'flutter-startup-spinner', 'flutter-startup-error', 'flutter-startup-retry'].map(id => [id, {
    hidden: id === 'flutter-startup-error', removed: false, classes: [],
    classList: { add(value) { nodes[id].classes.push(value); } },
    remove() { this.removed = true; }, addEventListener(type, fn) { this[type] = fn; },
  }]));
  const window = {
    location: { origin: 'https://cabinet.synthetic.test', reload() { reloads++; } },
    setTimeout(fn, delay) { timers.set(++timerID, { at: time + delay, fn }); return timerID; },
    clearTimeout(id) { timers.delete(id); },
    addEventListener(type, fn) { if (!listeners.has(type)) listeners.set(type, new Set()); listeners.get(type).add(fn); },
    removeEventListener(type, fn) { listeners.get(type)?.delete(fn); },
  };
  const document = { baseURI: base, getElementById: id => nodes[id] };
  const context = vm.createContext({ window, document, URL, _flutter: { loader: { load(value) { config = value; } } } });
  vm.runInContext(guard, context);
  return { window, nodes, context, get config() { return config; }, get reloads() { return reloads; },
    boot(load) { if (load) context._flutter.loader.load = load; vm.runInContext(bootstrap, context); },
    event(type) { for (const fn of [...(listeners.get(type) ?? [])]) fn(); },
    tick(ms) { time += ms; for (const [id, timer] of [...timers]) if (timer.at <= time) { timers.delete(id); timer.fn(); } },
  };
}

test('same-origin CanvasKit respects a local base path and rejects cross-origin base', () => {
  for (const [base, expected] of [['https://cabinet.synthetic.test/sub/', 'https://cabinet.synthetic.test/sub/canvaskit/'],
    ['https://foreign.synthetic.test/sub/', 'https://cabinet.synthetic.test/canvaskit/']]) {
    const f = fixture(base); f.boot(); assert.equal(f.config.config.canvasKitBaseUrl, expected);
  }
});

test('pending engine shows bounded bilingual retry without reloading automatically', async () => {
  const f = fixture(); f.boot();
  void f.config.onEntrypointLoaded({ initializeEngine: () => new Promise(() => {}) });
  f.tick(44999); assert.equal(f.nodes['flutter-startup-error'].hidden, true);
  f.tick(1); assert.equal(f.nodes['flutter-startup-error'].hidden, false);
  assert.equal(f.nodes['flutter-startup-spinner'].hidden, true); assert.equal(f.reloads, 0);
  f.nodes['flutter-startup-retry'].click(); assert.equal(f.reloads, 1);
  assert.match(html, /Повторить \/ 重试/);
});

test('engine and runApp rejections display retry without exposing error contents', async () => {
  for (const stage of ['engine', 'runApp']) {
    const f = fixture(); f.boot();
    const error = new Error('synthetic-private-diagnostic');
    await assert.rejects(f.config.onEntrypointLoaded({ initializeEngine: async () => {
      if (stage === 'engine') throw error;
      return { runApp: async () => { throw error; } };
    } }));
    assert.equal(f.nodes['flutter-startup-error'].hidden, false);
    assert.ok(!html.includes(error.message)); assert.equal(f.reloads, 0);
  }
});

test('loader sync/promise errors and script resources show the same retry', async () => {
  for (const mode of ['sync', 'promise', 'script', 'rejection']) {
    const f = fixture();
    if (mode === 'sync') f.boot(() => { throw new Error('synthetic'); });
    if (mode === 'promise') { f.boot(() => Promise.reject(new Error('synthetic'))); await Promise.resolve(); }
    if (mode === 'script') f.event('error');
    if (mode === 'rejection') f.event('unhandledrejection');
    assert.equal(f.nodes['flutter-startup-error'].hidden, false, mode); assert.equal(f.reloads, 0);
  }
});

test('late first frame removes a timed-out error and later errors cannot cover app', () => {
  const f = fixture(); f.tick(45000); assert.equal(f.nodes['flutter-startup-error'].hidden, false);
  f.event('flutter-first-frame'); assert.deepEqual(f.nodes['flutter-splash'].classes, ['hidden']);
  f.tick(380); assert.equal(f.nodes['flutter-splash'].removed, true);
  f.window.twoaWebStartup.fail(); f.event('error'); f.tick(90000);
  assert.equal(f.reloads, 0); assert.deepEqual(f.nodes['flutter-splash'].classes, ['hidden']);
});

test('successful first frame clears deadline and never displays an error', async () => {
  const f = fixture(); f.boot();
  await f.config.onEntrypointLoaded({ initializeEngine: async () => ({ runApp: async () => f.event('flutter-first-frame') }) });
  f.tick(45000); assert.equal(f.nodes['flutter-startup-error'].hidden, true);
  assert.equal(f.nodes['flutter-splash'].removed, true); assert.equal(f.reloads, 0);
});
