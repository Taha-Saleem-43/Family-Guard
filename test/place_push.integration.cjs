const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const { createHash } = require('node:crypto');
const req = createRequire(resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = req('firebase-admin/app');
const { getFirestore, Timestamp } = req('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-family-guard' }, 'place-push-tests');
const db = getFirestore(app);
const { createPushHandlers, deliveryId } = require('../functions/features/push');
const messages = [];
let fail = false;
const push = createPushHandlers(db, { send: async (message) => {
  if (fail) throw Object.assign(new Error('temporary'), { code: 'messaging/internal-error' });
  messages.push(message); return 'accepted';
} }, 'place');
const request = (uid, data) => ({ auth: { uid }, data: { expectedUid: uid, ...data } });
const secret = '9'.repeat(64);
const device = createHash('sha256').update(secret).digest('hex').slice(0, 32);
async function event(id) {
  await db.doc('circles/place-push-family').set({ memberIds: ['pp-child', 'pp-parent', 'pp-sibling'] });
  for (const [uid, role] of [['pp-child', 'child'], ['pp-parent', 'parent'], ['pp-sibling', 'child']]) {
    await db.doc(`users/${uid}`).set({ role, circleId: 'place-push-family' });
  }
  await db.doc(`placeEvents/${id}`).set({ circleId: 'place-push-family', memberId: 'pp-child',
    memberName: 'Private child', placeId: 'home', placeName: 'Private home', type: 'arrive', timestamp: Timestamp.now() });
}
async function register(uid, version, proof = secret) {
  return push.register(request(uid, { installationSecret: proof,
    installationId: createHash('sha256').update(proof).digest('hex').slice(0, 32),
    version, platform: 'android', token: `place-token-${uid}-${version}` }));
}
after(() => deleteApp(app));
test('place delivery queues only parents and excludes names and locations', async () => {
  await event('pp-first');
  await register('pp-parent', 1);
  await register('pp-sibling', 1, '8'.repeat(64));
  await push.enqueue('pp-first');
  await push.enqueue('pp-first');
  const jobs = await db.collection('placePushDeliveries').where('alertId', '==', 'pp-first').get();
  assert.equal(jobs.size, 1);
  await push.process(jobs.docs[0].id);
  await push.process(jobs.docs[0].id);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].data.type, 'place');
  assert.equal(messages[0].android.notification.channelId, 'family_guard_activity');
  assert.equal(JSON.stringify(messages[0]).includes('Private'), false);
  assert.equal(messages[0].data.latitude, undefined);
  assert.equal((await push.acknowledge(request('pp-parent', { alertId: 'pp-first',
    installationId: device, registrationVersion: 1, kind: 'opened' }))).acknowledged, true);
});
test('a queued notification is cancelled if its parent loses the role', async () => {
  await event('pp-revoked');
  await push.enqueue('pp-revoked');
  await db.doc('users/pp-parent').update({ role: 'child' });
  const id = deliveryId('pp-revoked', device);
  await push.process(id);
  assert.equal((await db.doc(`placePushDeliveries/${id}`).get()).data().status, 'cancelled');
  await assert.rejects(push.acknowledge(request('pp-parent', { alertId: 'pp-first',
    installationId: device, registrationVersion: 1, kind: 'opened' })), { code: 'permission-denied' });
});
test('transient delivery errors retry one job and expired events are not sent', async () => {
  await event('pp-retry');
  await push.enqueue('pp-retry');
  const id = deliveryId('pp-retry', device);
  fail = true;
  await assert.rejects(push.process(id));
  fail = false;
  assert.equal((await db.doc(`placePushDeliveries/${id}`).get()).data().status, 'pending');
  await db.doc(`placePushDeliveries/${id}`).update({ nextAttemptAt: Timestamp.fromMillis(0) });
  await push.retryPending();
  assert.equal((await db.doc(`placePushDeliveries/${id}`).get()).data().status, 'sent');
  await event('pp-expired');
  await push.enqueue('pp-expired');
  await db.doc('placeEvents/pp-expired').update({ timestamp: Timestamp.fromMillis(Date.now() - 16 * 60000) });
  const expiredId = deliveryId('pp-expired', device);
  await push.process(expiredId);
  assert.equal((await db.doc(`placePushDeliveries/${expiredId}`).get()).data().status, 'expired');
});
test('removing the child before delivery cancels their queued activity', async () => {
  await event('pp-child-left');
  await push.enqueue('pp-child-left');
  await db.doc('circles/place-push-family').update({ memberIds: ['pp-parent', 'pp-sibling'] });
  const id = deliveryId('pp-child-left', device);
  await push.process(id);
  assert.equal((await db.doc(`placePushDeliveries/${id}`).get()).data().status, 'cancelled');
});
