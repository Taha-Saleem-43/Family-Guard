const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const requireFunctions = createRequire(resolve(__dirname, '../functions/package.json'));
const { getFirestore } = requireFunctions('firebase-admin/firestore');
const { getApps, deleteApp } = requireFunctions('firebase-admin/app');
const handlers = require('../functions');
const { inviteKey } = require('../functions/domain');
const db = getFirestore();
let sequence = 0;
const request = (uid, data) => ({ auth: uid ? { uid, token: {} } : null, data: { expectedUid: uid, ...data } });
async function fixture({ parent = false, child = false } = {}) {
  const prefix = `leave-${++sequence}`, owner = `${prefix}-owner`, peer = `${prefix}-peer`, kid = `${prefix}-child`;
  for (const uid of [owner, peer, kid]) {
    await db.doc(`users/${uid}`).set({ uid, role: 'child', displayName: uid, circleId: null });
  }
  const family = await handlers.createCircle.run(request(owner, { circleName: 'Leave test' }));
  if (parent) await handlers.joinCircle.run(request(peer, { inviteCode: family.parentInviteCode }));
  if (child) await handlers.joinCircle.run(request(kid, { inviteCode: family.childInviteCode }));
  const leave = (uid = owner, successorId, extra = {}) => handlers.leaveCircle.run(request(uid, { circleId: family.id, successorId, ...extra }));
  return { owner, peer, kid, family, leave };
}
after(async () => { await Promise.all(getApps().map(deleteApp)); });

test('leave rejects unauthenticated, stale-account, foreign-circle and child promotion requests', async () => {
  const f = await fixture({ child: true });
  await assert.rejects(f.leave(null), { code: 'unauthenticated' });
  await assert.rejects(f.leave(f.owner, null, { expectedUid: f.peer }), { code: 'failed-precondition' });
  await assert.rejects(f.leave(f.owner, f.kid), { code: 'failed-precondition' });
  await assert.rejects(f.leave(f.owner, f.peer), { code: 'failed-precondition' });
  await assert.rejects(f.leave(f.owner, null, { circleId: 'another-circle' }), { code: 'permission-denied' });
  assert.equal((await db.doc(`users/${f.owner}`).get()).data().circleId, f.family.id);
});
test('last parent cannot leave children; a deleting co-parent is ineligible', async () => {
  const f = await fixture({ parent: true, child: true });
  await db.doc(`users/${f.peer}`).update({ deletionRequested: true });
  await assert.rejects(f.leave(f.owner, f.peer), { code: 'failed-precondition' });
  const circle = (await db.doc(`circles/${f.family.id}`).get()).data();
  assert.ok(circle.memberIds.includes(f.owner));
});
test('handoff is atomic, rotates invites, clears live location and preserves accounts/history', async () => {
  const f = await fixture({ parent: true, child: true });
  await db.doc(`users/${f.owner}`).update({ latitude: 1, longitude: 2, lastLocationPointId: 'old' });
  await db.doc(`locations/${f.owner}`).set({ circleId: f.family.id, latitude: 1 });
  await db.doc(`locationHistory/${f.owner}/points/old`).set({ circleId: f.family.id });
  assert.equal((await f.leave(f.owner, f.peer)).left, true);
  const circle = (await db.doc(`circles/${f.family.id}`).get()).data();
  assert.deepEqual(new Set(circle.memberIds), new Set([f.peer, f.kid]));
  assert.equal(circle.createdBy, f.peer);
  assert.equal(circle.requiresParent, false);
  const profile = (await db.doc(`users/${f.owner}`).get()).data();
  assert.equal(profile.circleId, null);
  assert.equal(profile.role, 'child');
  assert.equal(profile.latitude, undefined);
  assert.equal(profile.lastLocationPointId, undefined);
  assert.equal((await db.doc(`locations/${f.owner}`).get()).exists, false);
  assert.equal((await db.doc(`locationHistory/${f.owner}/points/old`).get()).exists, true);
  for (const code of [f.family.parentInviteCode, f.family.childInviteCode]) {
    assert.equal((await db.doc(`circleInvites/${inviteKey(code)}`).get()).exists, false);
  }
  const invites = (await db.doc(`circles/${f.family.id}/private/invites`).get()).data();
  assert.notEqual(invites.parentInviteCode, f.family.parentInviteCode);
  await assert.rejects(handlers.joinCircle.run(request(f.owner, { inviteCode: f.family.parentInviteCode })), { code: 'not-found' });
  assert.equal((await f.leave(f.owner, f.peer)).left, true, 'lost response retry succeeds');
});
test('child can leave without transferring authority or changing other members', async () => {
  const f = await fixture({ child: true });
  await assert.rejects(f.leave(f.kid, f.owner), { code: 'permission-denied' });
  await f.leave(f.kid);
  const circle = (await db.doc(`circles/${f.family.id}`).get()).data();
  assert.deepEqual(circle.memberIds, [f.owner]);
  assert.equal(circle.createdBy, f.owner);
  assert.equal(circle.requiresParent, false);
});
test('sole member closes circle, removes bounded saved places/private docs and revokes invites', async () => {
  const f = await fixture();
  await db.doc(`places/${f.owner}-place`).set({ circleId: f.family.id });
  await db.doc(`circles/${f.family.id}/private/places`).set({ places: {} });
  const result = await f.leave();
  assert.equal(result.closed, true);
  for (const path of [`circles/${f.family.id}`, `circles/${f.family.id}/private/invites`,
    `circles/${f.family.id}/private/places`, `places/${f.owner}-place`]) {
    assert.equal((await db.doc(path).get()).exists, false);
  }
  assert.equal((await db.doc(`users/${f.owner}`).get()).exists, true);
});
test('active SOS must be resolved explicitly before departure', async () => {
  const f = await fixture();
  await db.doc(`sos_alerts/${f.owner}-sos`).set({ status: 'active', senderId: f.owner, circleId: f.family.id });
  await db.doc(`users/${f.owner}`).update({ activeSosId: `${f.owner}-sos` });
  await assert.rejects(f.leave(), { code: 'failed-precondition' });
  assert.equal((await db.doc(`sos_alerts/${f.owner}-sos`).get()).data().status, 'active');
});
test('concurrent parent departures cannot strand a child without a parent', async () => {
  const f = await fixture({ parent: true, child: true });
  const results = await Promise.allSettled([f.leave(f.owner, f.peer), f.leave(f.peer, f.owner)]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  const circle = (await db.doc(`circles/${f.family.id}`).get()).data();
  assert.equal(circle.memberIds.length, 2);
  assert.ok(circle.memberIds.includes(f.kid));
  assert.equal(circle.requiresParent, false);
});
test('retry from an old circle never detaches a newly created circle', async () => {
  const f = await fixture();
  await f.leave();
  const next = await handlers.createCircle.run(request(f.owner, { circleName: 'Next circle' }));
  await assert.rejects(f.leave(), { code: 'permission-denied' });
  assert.equal((await db.doc(`users/${f.owner}`).get()).data().circleId, next.id);
});
