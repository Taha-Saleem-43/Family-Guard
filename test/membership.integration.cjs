const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const requireFunctions = createRequire(resolve(__dirname, '../functions/package.json'));
const { getFirestore, Timestamp } = requireFunctions('firebase-admin/firestore');
const { getApps, deleteApp } = requireFunctions('firebase-admin/app');
const handlers = require('../functions');
const { inviteKey } = require('../functions/domain');
const db = getFirestore();
const request = (uid, data) => ({ auth: uid ? { uid, token: {} } : null, data });
let created;
before(async () => {
  for (const uid of ['creator', 'child', 'other', 'expired', 'parallel']) {
    await db.doc(`users/${uid}`).set({ uid, displayName: uid, role: 'child', circleId: null });
  }
});
after(async () => { await Promise.all(getApps().map(deleteApp)); });
test('membership and emergency endpoints reject a switched request identity', async () => {
  for (const name of ['createCircle', 'joinCircle', 'rotateCircleInvites', 'triggerSos', 'resolveSos']) {
    await assert.rejects(handlers[name].run(request('creator', { expectedUid: 'other' })), { code: 'failed-precondition' });
  }
  assert.equal((await db.doc('users/creator').get()).data().circleId, null);
});
test('unauthenticated creation and joins are rejected', async () => {
  await assert.rejects(handlers.createCircle.run(request(null, { circleName: 'Family' })), { code: 'unauthenticated' });
  await assert.rejects(handlers.joinCircle.run(request(null, { inviteCode: 'FAMILY-0000000000000000' })), { code: 'unauthenticated' });
});
test('creation atomically assigns creator membership and keeps invites private', async () => {
  await db.doc('users/creator').update({ latitude: 1, longitude: 2, lastSeen: 'old', lastLocationPointId: 'old' });
  await db.doc('locations/creator').set({ latitude: 1, longitude: 2 });
  created = await handlers.createCircle.run(request('creator', { circleName: 'Our family' }));
  const [user, circle, secrets] = await Promise.all([
    db.doc('users/creator').get(), db.doc(`circles/${created.id}`).get(),
    db.doc(`circles/${created.id}/private/invites`).get(),
  ]);
  assert.equal(user.data().role, 'parent');
  assert.equal(user.data().circleId, created.id);
  assert.equal(user.data().latitude, undefined);
  assert.equal(user.data().lastSeen, undefined);
  assert.equal(user.data().lastLocationPointId, undefined);
  assert.equal((await db.doc('locations/creator').get()).exists, false);
  assert.deepEqual(circle.data().memberIds, ['creator']);
  assert.equal(circle.data().parentInviteCode, undefined);
  assert.equal(secrets.data().parentInviteCode, created.parentInviteCode);
  await assert.rejects(handlers.createCircle.run(request('creator', { circleName: 'Another family' })), { code: 'already-exists' });
});
test('valid child invite joins once and cannot promote an existing member', async () => {
  await db.doc('users/child').update({ latitude: 3, longitude: 4, lastSeen: 'old' });
  await db.doc('locations/child').set({ latitude: 3, longitude: 4 });
  const joined = await handlers.joinCircle.run(request('child', { inviteCode: created.childInviteCode }));
  assert.equal(joined.role, 'child');
  assert.equal(joined.circleId, created.id);
  assert.equal((await db.doc('users/child').get()).data().latitude, undefined);
  assert.equal((await db.doc('locations/child').get()).exists, false);
  await db.doc('users/child').update({ latitude: 5 });
  await handlers.joinCircle.run(request('child', { inviteCode: created.parentInviteCode }));
  assert.equal((await db.doc('users/child').get()).data().role, 'child');
  assert.equal((await db.doc('users/child').get()).data().latitude, 5);
  const members = (await db.doc(`circles/${created.id}`).get()).data().memberIds;
  assert.equal(members.filter((uid) => uid === 'child').length, 1);
});
test('unknown and expired invites cannot produce membership', async () => {
  await assert.rejects(handlers.joinCircle.run(request('other', { inviteCode: 'FAMILY-0000000000000000' })), { code: 'not-found' });
  const code = 'FAMILY-1111111111111111';
  await db.doc(`circleInvites/${inviteKey(code)}`).set({ circleId: created.id, role: 'child', revoked: false, expiresAt: Timestamp.fromMillis(0) });
  await assert.rejects(handlers.joinCircle.run(request('expired', { inviteCode: code })), { code: 'not-found' });
  assert.equal((await db.doc('users/other').get()).data().circleId, null);
  assert.equal((await db.doc('users/expired').get()).data().circleId, null);
});
test('simultaneous circle creation admits only one membership', async () => {
  const results = await Promise.allSettled([
    handlers.createCircle.run(request('parallel', { circleName: 'First family' })),
    handlers.createCircle.run(request('parallel', { circleName: 'Second family' })),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
});
test('failed invite redemption is counted and rate limited', async () => {
  await db.doc('inviteAttempts/other').set({ count: 10, windowStart: Timestamp.now() });
  await assert.rejects(handlers.joinCircle.run(request('other', { inviteCode: created.childInviteCode })), { code: 'resource-exhausted' });
});
