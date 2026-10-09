const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const req = createRequire(resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = req('firebase-admin/app');
const { getFirestore, Timestamp } = req('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-family-guard' });
const db = getFirestore(app);
const { createAccountDeletionHandlers } = require('../functions/features/accounts');
const calls = [];
let fail = false;
const handlers = createAccountDeletionHandlers(db, {
  updateUser: async (uid) => { calls.push(`disable:${uid}`); if (fail) throw Object.assign(new Error('temporary'), { code: 'unavailable' }); },
  deleteUser: async (uid) => { calls.push(`delete:${uid}`); },
});
const request = (uid, age = 0) => ({ auth: { uid, token: { auth_time: Date.now() / 1000 - age } }, data: { expectedUid: uid } });
after(() => deleteApp(app));

test('recent verification and expected identity are required', async () => {
  await assert.rejects(handlers.request(request('stale', 600)), { code: 'failed-precondition' });
  const changed = request('changed'); changed.data.expectedUid = 'other';
  await assert.rejects(handlers.request(changed), { code: 'failed-precondition' });
  assert.equal((await db.doc('accountDeletions/stale').get()).exists, false);
});
test('deletion detaches only its member and preserves other family data', async () => {
  await db.doc('users/delete-parent').set({ circleId: 'deletion-family', role: 'parent' });
  await db.doc('users/keep-child').set({ circleId: 'deletion-family', role: 'child' });
  await db.doc('circles/deletion-family').set({ memberIds: ['delete-parent', 'keep-child'], createdBy: 'delete-parent' });
  await db.doc('locationHistory/delete-parent/points/one').set({ timestamp: Timestamp.now() });
  await db.doc('locationHistory/keep-child/points/one').set({ timestamp: Timestamp.now() });
  await db.doc('sos_alerts/deleted-alert').set({ senderId: 'delete-parent' });
  await db.doc('places/deleted-place').set({ createdBy: 'delete-parent' });
  await handlers.request(request('delete-parent'));
  assert.equal((await db.doc('users/delete-parent').get()).data().deletionRequested, true);
  const family = (await db.doc('circles/deletion-family').get()).data();
  assert.deepEqual(family.memberIds, ['keep-child']);
  assert.equal(family.requiresParent, true);
  await handlers.process('delete-parent');
  for (const path of ['users/delete-parent', 'locationHistory/delete-parent/points/one', 'sos_alerts/deleted-alert', 'places/deleted-place']) {
    assert.equal((await db.doc(path).get()).exists, false, path);
  }
  assert.equal((await db.doc('locationHistory/keep-child/points/one').get()).exists, true);
  assert.equal((await db.doc('accountDeletions/delete-parent').get()).data().status, 'complete');
  const count = calls.length;
  await handlers.process('delete-parent');
  await handlers.request(request('delete-parent', 600));
  assert.equal(calls.length, count);
});
test('interrupted cleanup returns to pending and safely retries', async () => {
  await db.doc('users/retry-delete').set({ circleId: null });
  await handlers.request(request('retry-delete'));
  fail = true;
  await assert.rejects(handlers.process('retry-delete'), { code: 'unavailable' });
  assert.equal((await db.doc('accountDeletions/retry-delete').get()).data().status, 'pending');
  fail = false;
  await handlers.process('retry-delete');
  assert.equal((await db.doc('accountDeletions/retry-delete').get()).data().status, 'complete');
});
test('last member deletion closes private invites and circle data', async () => {
  await db.doc('users/last-delete').set({ circleId: 'empty-delete', role: 'parent' });
  await db.doc('circles/empty-delete').set({ memberIds: ['last-delete'], createdBy: 'last-delete' });
  await db.doc('circles/empty-delete/private/invites').set({ parentInviteCode: 'secret' });
  await db.doc('circleInvites/empty-delete-code').set({ circleId: 'empty-delete' });
  await db.doc('places/empty-delete-place').set({ circleId: 'empty-delete' });
  await handlers.request(request('last-delete'));
  assert.equal((await db.doc('circles/empty-delete').get()).exists, false);
  await handlers.process('last-delete');
  for (const path of ['circles/empty-delete/private/invites', 'circleInvites/empty-delete-code', 'places/empty-delete-place']) {
    assert.equal((await db.doc(path).get()).exists, false, path);
  }
});
test('active leases prevent duplicate work; expired leases recover', async () => {
  await db.doc('accountDeletions/lease-delete').set({ status: 'processing', leaseOwner: 'old', leaseUntil: Timestamp.fromMillis(Date.now() + 60000) });
  const count = calls.length;
  await handlers.process('lease-delete');
  assert.equal(calls.length, count);
  await db.doc('accountDeletions/lease-delete').update({ leaseUntil: Timestamp.fromMillis(0) });
  await handlers.retryPending();
  assert.equal((await db.doc('accountDeletions/lease-delete').get()).data().status, 'complete');
});
