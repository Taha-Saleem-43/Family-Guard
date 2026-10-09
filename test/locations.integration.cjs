const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const req = createRequire(resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = req('firebase-admin/app');
const { getFirestore } = req('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-family-guard' }, 'location-integration');
const db = getFirestore(app);
const { createLocationHandlers } = require('../functions/features/locations');
const ingest = createLocationHandlers(db).ingest;
after(() => deleteApp(app));
function fix(id, age = 0, latitude = 1) {
  return { id: id.repeat(64), capturedAt: Date.now() - age, latitude, longitude: 2,
    speedMph: 0, movementActivity: 'stationary', batteryLevel: -1, isCharging: false };
}
async function setup(uid) {
  await db.doc(`users/${uid}`).set({ role: 'child', circleId: uid });
  await db.doc(`circles/${uid}`).set({ memberIds: [uid] });
}
const upload = (uid, fixes, circleId = uid) => ingest({ auth: { uid }, data: { expectedUid: uid, circleId, fixes } });
test('retries deduplicate history and cannot replace newer live coordinates', async () => {
  const uid = 'location-retry'; await setup(uid);
  const old = fix('a', 20000, 3), recent = fix('b', 1000, 4);
  await upload(uid, [recent]);
  await upload(uid, [old]);
  await upload(uid, [recent]);
  assert.equal((await db.doc(`users/${uid}`).get()).data().latitude, 4);
  assert.equal((await db.collection(`locationHistory/${uid}/points`).get()).size, 2);
  await assert.rejects(upload(uid, [{ ...recent, latitude: 5 }]), { code: 'already-exists' });
});
test('concurrent processes converge on the newest capture', async () => {
  const uid = 'location-concurrent'; await setup(uid);
  await Promise.all([upload(uid, [fix('c', 10000, 10)]), upload(uid, [fix('d', 1000, 20)])]);
  assert.equal((await db.doc(`users/${uid}`).get()).data().latitude, 20);
});
test('offline history retains capture time without presenting an old location as live', async () => {
  const uid = 'location-offline'; await setup(uid);
  const point = fix('e', 86400000);
  assert.equal((await upload(uid, [point])).liveUpdated, false);
  const history = (await db.doc(`locationHistory/${uid}/points/${point.id}`).get()).data();
  assert.equal(history.timestamp.toMillis(), point.capturedAt);
  assert.equal(history.expireAt.toMillis(), point.capturedAt + 30 * 86400000);
  assert.equal((await db.doc(`users/${uid}`).get()).data().latitude, undefined);
});
test('changed circle, parent role, membership removal and deletion reject replay', async () => {
  const uid = 'location-context'; await setup(uid);
  const point = fix('f');
  await assert.rejects(upload(uid, [point], 'other'), { code: 'failed-precondition' });
  await db.doc(`users/${uid}`).update({ role: 'parent' });
  await assert.rejects(upload(uid, [point]), { code: 'failed-precondition' });
  await db.doc(`users/${uid}`).update({ role: 'child' });
  await db.doc(`circles/${uid}`).update({ memberIds: [] });
  await assert.rejects(upload(uid, [point]), { code: 'failed-precondition' });
  await db.doc(`circles/${uid}`).update({ memberIds: [uid] });
  await db.doc(`accountDeletions/${uid}`).set({ status: 'pending' });
  await assert.rejects(upload(uid, [point]), { code: 'failed-precondition' });
});
test('invalid batches are rejected without partial writes', async () => {
  const uid = 'location-invalid'; await setup(uid);
  const valid = fix('1');
  for (const invalid of [{ ...valid, latitude: 91 }, fix('2', -60000), fix('3', 8 * 86400000),
    { ...valid, batteryLevel: 101 }, { ...valid, id: '../escape' }]) {
    await assert.rejects(upload(uid, [valid, invalid]), { code: 'invalid-argument' });
  }
  await assert.rejects(upload(uid, [valid, valid]), { code: 'invalid-argument' });
  assert.equal((await db.collection(`locationHistory/${uid}/points`).get()).size, 0);
});
test('per-account recovery budget bounds writes before expensive processing', async () => {
  const uid = 'location-budget'; await setup(uid);
  const { Timestamp } = req('firebase-admin/firestore');
  await db.doc(`users/${uid}`).update({ locationIngestWindow: Timestamp.now(), locationIngestCount: 599 });
  await assert.rejects(upload(uid, [fix('4'), fix('5')]), { code: 'resource-exhausted' });
  assert.equal((await db.collection(`locationHistory/${uid}/points`).get()).size, 0);
  await upload(uid, [fix('6')]);
  await assert.rejects(upload(uid, [fix('7')]), { code: 'resource-exhausted' });
});
