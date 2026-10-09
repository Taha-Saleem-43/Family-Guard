const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const { createHash } = require('node:crypto');
const req = createRequire(resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = req('firebase-admin/app');
const { getFirestore, Timestamp } = req('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-family-guard' }, 'push-integration');
const db = getFirestore(app);
const { createPushHandlers, deliveryId } = require('../functions/features/push');
const sent = [];
let failure;
const push = createPushHandlers(db, { send: async (message) => {
  if (failure) throw Object.assign(new Error('mock FCM failure'), { code: failure });
  sent.push(message); return `mock:${sent.length}`;
} });
const secret = '1'.repeat(64);
const device = createHash('sha256').update(secret).digest('hex').slice(0, 32);
const request = (uid, data) => ({ auth: { uid }, data: { expectedUid: uid, ...data } });
const register = (uid, version, proof = secret) => push.register(request(uid, {
  installationId: createHash('sha256').update(proof).digest('hex').slice(0, 32), installationSecret: proof,
  version, token: `mock-token-for-${uid}-${version}`, platform: 'android',
}));
async function family(alertId) {
  await db.doc('users/push-sender').set({ circleId: 'push-family', role: 'child' });
  await db.doc('users/push-receiver').set({ circleId: 'push-family', role: 'parent' });
  await db.doc('circles/push-family').set({ memberIds: ['push-sender', 'push-receiver'] });
  await db.doc(`sos_alerts/${alertId}`).set({ circleId: 'push-family', senderId: 'push-sender',
    senderName: 'Private name', latitude: 12, longitude: 34, timestamp: new Date().toISOString(), status: 'active' });
}
after(() => deleteApp(app));

test('registry is version fenced across account switches and logout', async () => {
  await family('push-first');
  await db.doc('users/push-other').set({ circleId: null });
  await register('push-receiver', 1);
  await register('push-other', 2);
  await assert.rejects(register('push-receiver', 1), { code: 'aborted' });
  assert.equal((await db.doc(`pushDevices/${device}`).get()).data().uid, 'push-other');
  assert.equal((await push.unregister(request('push-receiver', { installationId: device, installationSecret: secret, version: 3 }))).removed, false);
  await register('push-receiver', 4);
  await push.unregister(request('push-receiver', { installationId: device, installationSecret: secret, version: 5 }));
  await assert.rejects(register('push-receiver', 4), { code: 'aborted' });
  assert.equal((await db.doc(`pushDevices/${device}`).get()).data().token, undefined);
  await register('push-receiver', 6);
});
test('fanout excludes sender; retries preserve one private job and message', async () => {
  await register('push-sender', 1, '2'.repeat(64));
  await push.enqueue('push-first');
  await push.enqueue('push-first');
  const jobs = await db.collection('sosPushDeliveries').where('alertId', '==', 'push-first').get();
  assert.equal(jobs.size, 1);
  const id = deliveryId('push-first', device);
  await push.process(id);
  await push.process(id);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].data.recipientUid, 'push-receiver');
  assert.equal(sent[0].notification.body.includes('Private name'), false);
  assert.equal(sent[0].data.latitude, undefined);
  assert.equal(sent[0].data.senderName, undefined);
  assert.equal((await db.doc(`sosPushDeliveries/${id}`).get()).data().receivedAt, undefined);
});
test('only the intended current account can acknowledge a delivery', async () => {
  const data = { installationId: device, registrationVersion: 6, alertId: 'push-first', kind: 'opened' };
  await assert.rejects(push.acknowledge(request('push-other', data)), { code: 'permission-denied' });
  assert.equal((await push.acknowledge(request('push-receiver', data))).active, true);
  const first = (await db.doc(`sosPushDeliveries/${deliveryId('push-first', device)}`).get()).data().openedAt;
  await push.acknowledge(request('push-receiver', data));
  assert.equal((await db.doc(`sosPushDeliveries/${deliveryId('push-first', device)}`).get()).data().openedAt.toMillis(), first.toMillis());
});
test('queued delivery follows token rotation for the same account', async () => {
  await family('push-rotation');
  await push.enqueue('push-rotation');
  await register('push-receiver', 7);
  await push.process(deliveryId('push-rotation', device));
  assert.equal(sent.at(-1).token, 'mock-token-for-push-receiver-7');
});
test('membership removal cancels queued delivery', async () => {
  await family('push-removed'); await push.enqueue('push-removed');
  await db.doc('users/push-receiver').update({ circleId: null });
  const count = sent.length;
  await push.process(deliveryId('push-removed', device));
  assert.equal(sent.length, count);
  assert.equal((await db.doc(`sosPushDeliveries/${deliveryId('push-removed', device)}`).get()).data().status, 'cancelled');
});
test('transient FCM failure is durable and retries; stale tokens are disabled', async () => {
  await family('push-retry'); await push.enqueue('push-retry');
  const id = deliveryId('push-retry', device);
  failure = 'messaging/server-unavailable';
  await assert.rejects(push.process(id), { code: failure });
  assert.equal((await db.doc(`sosPushDeliveries/${id}`).get()).data().status, 'pending');
  failure = undefined;
  await db.doc(`sosPushDeliveries/${id}`).update({ nextAttemptAt: Timestamp.fromMillis(0) });
  await push.retryPending();
  assert.equal((await db.doc(`sosPushDeliveries/${id}`).get()).data().status, 'sent');
  await family('push-invalid'); await push.enqueue('push-invalid');
  failure = 'messaging/registration-token-not-registered';
  await push.process(deliveryId('push-invalid', device));
  assert.equal((await db.doc(`pushDevices/${device}`).get()).data().enabled, false);
  failure = undefined;
});
test('resolved alerts expire queued pushes without sending', async () => {
  await register('push-receiver', 8);
  await family('push-resolved'); await push.enqueue('push-resolved');
  await db.doc('sos_alerts/push-resolved').update({ status: 'resolved' });
  const count = sent.length;
  await push.process(deliveryId('push-resolved', device));
  assert.equal(sent.length, count);
  assert.equal((await db.doc(`sosPushDeliveries/${deliveryId('push-resolved', device)}`).get()).data().status, 'expired');
});
test('deleting accounts cannot register and registry has a device bound', async () => {
  await db.doc('accountDeletions/push-other').set({ status: 'pending' });
  await assert.rejects(register('push-other', 10), { code: 'failed-precondition' });
  await db.doc('users/push-bound').set({ circleId: null });
  for (let i = 101; i <= 110; i++) await register('push-bound', 1, i.toString(16).padStart(64, '0'));
  await assert.rejects(register('push-bound', 1, 'f'.repeat(64)), { code: 'resource-exhausted' });
});
test('knowing a delivery installation ID cannot take over its registration', async () => {
  await assert.rejects(push.register(request('push-sender', {
    installationId: device, installationSecret: '2'.repeat(64), version: 1000,
    token: 'mock-attacker-token-value', platform: 'android',
  })), { code: 'invalid-argument' });
  assert.equal((await db.doc(`pushDevices/${device}`).get()).data().uid, 'push-receiver');
});
