const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const requireFunctions = createRequire(resolve(__dirname, '../functions/package.json'));
const { getFirestore } = requireFunctions('firebase-admin/firestore');
const { getApps, deleteApp } = requireFunctions('firebase-admin/app');
const handlers = require('../functions');
const db = getFirestore();
const request = (uid, data) => ({ auth: uid ? { uid, token: {} } : null, data });
const send = (uid, id, extra = {}) => handlers.triggerSos.run(request(uid, {
  circleId: 'sos-family', requestId: id.repeat(32), ...extra,
}));
const resolveAlert = (uid, alertId) => handlers.resolveSos.run(request(uid, { alertId }));
let first;
before(async () => {
  await db.doc('circles/sos-family').set({ memberIds: ['sos-sender', 'sos-parent', 'sos-concurrent'] });
  for (const uid of ['sos-sender', 'sos-parent', 'sos-concurrent']) {
    await db.doc(`users/${uid}`).set({ uid, circleId: 'sos-family', displayName: 'Verified name', role: 'child' });
  }
  await db.doc('users/sos-outsider').set({ uid: 'sos-outsider', circleId: 'other', role: 'parent' });
});
after(async () => { await Promise.all(getApps().map(deleteApp)); });

test('auth, membership and coordinate validation reject forged emergencies', async () => {
  await assert.rejects(send(null, 'a'), { code: 'unauthenticated' });
  await assert.rejects(send('sos-outsider', 'a'), { code: 'permission-denied' });
  await assert.rejects(send('sos-sender', 'a', { latitude: 91, longitude: 2 }), { code: 'invalid-argument' });
  await assert.rejects(send('sos-sender', 'a', { latitude: 1 }), { code: 'invalid-argument' });
  await assert.rejects(send('sos-sender', 'a', { requestId: '../bad' }), { code: 'invalid-argument' });
});
test('creation is atomic and backend-owned; active emergencies do not expire silently', async () => {
  first = await send('sos-sender', 'a', { senderId: 'sos-parent', senderName: 'Forged', latitude: 1, longitude: 2 });
  const alert = (await db.doc(`sos_alerts/${first.alertId}`).get()).data();
  const user = (await db.doc('users/sos-sender').get()).data();
  assert.equal(alert.senderId, 'sos-sender');
  assert.equal(alert.senderName, 'Verified name');
  assert.equal(user.activeSosId, first.alertId);
  assert.equal(user.isSosActive, true);
  assert.equal(alert.status, 'active');
  assert.equal(alert.expireAt, undefined);
});
test('retries preserve one alert and a new key returns the current active alert', async () => {
  const retried = await send('sos-sender', 'a', { latitude: 3, longitude: 4 });
  const differentKey = await send('sos-sender', 'b');
  assert.equal(retried.alertId, first.alertId);
  assert.equal(differentKey.alertId, first.alertId);
  assert.equal((await db.doc(`sos_alerts/${first.alertId}`).get()).data().latitude, 1);
});
test('simultaneous distinct requests create only one active emergency', async () => {
  const results = await Promise.all([send('sos-concurrent', 'a'), send('sos-concurrent', 'b')]);
  assert.equal(results[0].alertId, results[1].alertId);
  const alerts = await db.collection('sos_alerts').where('senderId', '==', 'sos-concurrent').get();
  assert.equal(alerts.size, 1);
});
test('only sender resolves, retries are safe, resolved send keys cannot reopen', async () => {
  await assert.rejects(resolveAlert('sos-parent', first.alertId), { code: 'permission-denied' });
  await resolveAlert('sos-sender', first.alertId);
  await resolveAlert('sos-sender', first.alertId);
  assert.equal((await send('sos-sender', 'a')).status, 'resolved');
  assert.equal((await db.doc('users/sos-sender').get()).data().isSosActive, false);
  assert.ok((await db.doc(`sos_alerts/${first.alertId}`).get()).data().expireAt.toMillis()
    > Date.now() + 29 * 86400000);
});
test('resolving an old emergency never erases a newer active emergency', async () => {
  const next = await send('sos-sender', 'c');
  await resolveAlert('sos-sender', first.alertId);
  const user = (await db.doc('users/sos-sender').get()).data();
  assert.equal(user.activeSosId, next.alertId);
  assert.equal(user.isSosActive, true);
});
