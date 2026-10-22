// Explicit local QA: only this task's disposable emulator and synthetic fixtures.
// No packages, production code instrumentation, or real-phone targeting.
import {execFileSync} from 'node:child_process';
import {copyFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {DatabaseSync} from 'node:sqlite';

const [revision, countArg, theme] = process.argv.slice(2);
if (!['baseline', 'candidate'].includes(revision) ||
    !['30', '10000'].includes(countArg) ||
    !['light', 'dark', 'glass'].includes(theme)) {
  throw Error('Usage: node tools/v034-performance.mjs baseline|candidate 30|10000 light|dark|glass');
}
const qaRoot = 'D:/Codex/PocketFlow-v034-20261021/.local';
const out = resolve(qaRoot, 'evidence/performance');
mkdirSync(out, {recursive: true});
const name = `${revision}-${countArg}-${theme}`;
const fixture = resolve(out, `${name}.sqlite`);
copyFileSync(resolve(qaRoot, `fixtures/synthetic-${countArg}.sqlite`), fixture);
const db = new DatabaseSync(fixture);
const row = db.prepare("SELECT value_json FROM personal_state WHERE key='profile'").get();
const profile = {...JSON.parse(row.value_json), theme: theme === 'dark' ? 'dark' : 'light', surfaceStyle: theme === 'glass' ? 'glass' : 'classic', locale: 'zh_Hans'};
db.prepare("UPDATE personal_state SET value_json=? WHERE key='profile'").run(JSON.stringify(profile));
db.close();

const adbPath = 'D:/Codex/PocketFlowTools/android-sdk/platform-tools/adb.exe';
const adb = (...args) => execFileSync(adbPath, ['-s', 'emulator-5590', ...args], {encoding: 'utf8', maxBuffer: 16 * 1024 * 1024});
const pause = ms => new Promise(done => setTimeout(done, ms));
adb('shell', 'am', 'force-stop', 'cn.pocketflow');
adb('push', fixture, '/data/local/tmp/pf034-fixture.sqlite');
const owner = adb('shell', 'stat', '-c', '%u:%g', '/data/user/0/cn.pocketflow').trim();
if (!/^\d+:\d+$/.test(owner)) throw Error('Unexpected synthetic app owner');
adb('shell', 'rm', '-f', '/data/user/0/cn.pocketflow/app_flutter/pocketflow.sqlite-wal', '/data/user/0/cn.pocketflow/app_flutter/pocketflow.sqlite-shm');
adb('shell', 'cp', '/data/local/tmp/pf034-fixture.sqlite', '/data/user/0/cn.pocketflow/app_flutter/pocketflow.sqlite');
adb('shell', 'chown', owner, '/data/user/0/cn.pocketflow/app_flutter/pocketflow.sqlite');
adb('logcat', '-c');
const cold = adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.RUN', '-n', 'cn.pocketflow/.MainActivity', '--ez', 'enable-dart-profiling', 'true', '--ez', 'disable-service-auth-codes', 'true');
await pause(1800);
const logs = adb('logcat', '-d', '-s', 'flutter');
writeFileSync(resolve(out, `${name}-launch.log`), cold + '\n' + logs);
const match = logs.match(/Dart VM service is listening on http:\/\/127\.0\.0\.1:(\d+)\//);
if (!match) throw Error('Profile VM service unavailable; no measurements accepted');
adb('forward', 'tcp:8364', `tcp:${match[1]}`);
const socket = new WebSocket('ws://127.0.0.1:8364/ws');
await new Promise((done, reject) => {socket.onopen = done; socket.onerror = reject;});
let sequence = 0;
const pending = new Map();
socket.onmessage = event => {
  const value = JSON.parse(event.data);
  const entry = pending.get(value.id);
  if (!entry) return;
  pending.delete(value.id);
  clearTimeout(entry.timeout);
  if (value.error) entry.reject(Error(JSON.stringify(value.error)));
  else entry.done(value.result);
};
function rpc(method, params = {}) {
  return new Promise((done, reject) => {
    const id = ++sequence;
    const timeout = setTimeout(() => {pending.delete(id); reject(Error(`VM timeout: ${method}`));}, 10000);
    pending.set(id, {done, reject, timeout});
    socket.send(JSON.stringify({jsonrpc: '2.0', id, method, params}));
  });
}
const vm = await rpc('getVM');
const isolateId = vm.isolates.find(i => i.name === 'main')?.id;
if (!isolateId) throw Error('Main isolate missing');
const frames = () => rpc('ext.pocketflow.qa.frames', {isolateId, reset: 'true'});
const samples = {coldStart: await frames()};
const tap = async (x, y) => {adb('shell', 'input', 'tap', String(x), String(y)); await pause(220);};
await tap(320, 2140);
adb('shell', 'uiautomator', 'dump', '/sdcard/pf034-perf.xml');
const loaded = adb('shell', 'cat', '/sdcard/pf034-perf.xml');
writeFileSync(resolve(out, `${name}-loaded.xml`), loaded);
if (!loaded.includes(`共 ${Number(countArg) / 2} 笔`)) {
  throw Error('Displayed ledger count does not match synthetic fixture; reject sample');
}
async function sample(label, work) {
  await frames();
  await work();
  await pause(1200); // QA waits for batched FrameTiming delivery; never a product delay.
  samples[label] = await frames();
}
await sample('switchTabs', async () => {
  for (let i = 0; i < 4; i++) {
    await tap(320, 2140); await tap(760, 2140); await tap(135, 2140);
  }
});
await tap(320, 2140);
await sample('scrollLedger', async () => {
  for (let i = 0; i < 4; i++) adb('shell', 'input', 'swipe', '520', '1750', '520', '620', '350');
  for (let i = 0; i < 4; i++) adb('shell', 'input', 'swipe', '520', '620', '520', '1750', '350');
});
await sample('searchLedger', async () => {
  await tap(300, 350);
  adb('shell', 'input', 'text', 'PF034');
  await pause(300);
  adb('shell', 'input', 'keyevent', '67', '67', '67', '67', '67');
  adb('shell', 'input', 'keyevent', '4');
});
await tap(540, 2140);
await sample('saveContinue', async () => {
  await tap(210, 1500);
  await tap(290, 2160);
});
adb('shell', 'uiautomator', 'dump', '/sdcard/pf034-perf.xml');
writeFileSync(resolve(out, `${name}-final.xml`), adb('shell', 'cat', '/sdcard/pf034-perf.xml'));
adb('shell', 'am', 'force-stop', 'cn.pocketflow');
socket.close();
const afterPath = resolve(out, `${name}-after.sqlite`);
adb('pull', '/data/user/0/cn.pocketflow/app_flutter/pocketflow.sqlite', afterPath);
const after = new DatabaseSync(afterPath, {readOnly: true});
const persistedCount = after.prepare('SELECT count(*) AS count FROM ledger_entries').get().count;
after.close();
if (persistedCount !== Number(countArg) + 1) throw Error('Save did not persist exactly one synthetic entry; reject sample');
const result = {revision, baseline: 'b6c0e71a2a51db8bd8a56d90f68c77e2dd34e3b0', count: Number(countArg), perMonth: Number(countArg) / 2, verifiedDisplayedCount: true, theme, mode: 'Profile', serial: 'emulator-5590', refreshHz: 60, budgetUs: 1000000 / 60, renderer: 'Impeller OpenGLES / host GPU', coldAmStart: cold, samples};
result.persistedCountAfterSave = persistedCount;
const quantile = (values, p) => values[Math.min(values.length - 1, Math.ceil(values.length * p) - 1)];
result.summary = Object.fromEntries(Object.entries(samples).map(([label, sample]) => {
  const values = sample.frames.map(f => Math.max(f.buildUs, f.rasterUs)).sort((a,b) => a-b);
  if (!values.length) throw Error(`No frames for ${label}`);
  return [label, {frames: values.length, p50Ms: quantile(values, .5) / 1000, p90Ms: quantile(values, .9) / 1000, p99Ms: quantile(values, .99) / 1000, overBudgetPercent: values.filter(v => v > result.budgetUs).length / values.length * 100}];
}));
writeFileSync(resolve(out, `${name}.json`), JSON.stringify(result, null, 2));
console.log(JSON.stringify({name, summary: result.summary}));
