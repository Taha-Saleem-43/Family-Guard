const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const requireFunctions = createRequire(resolve(__dirname, '../functions/package.json'));
const { getFirestore } = requireFunctions('firebase-admin/firestore');
const { getApps, deleteApp } = requireFunctions('firebase-admin/app');
const handlers = require('../functions');
const { inviteKey } = require('../functions/domain');
const db = getFirestore();
const request = (uid, data) => ({ auth: uid ? { uid, token: {} } : null, data });
let family;
let replacement;
before(async () => {
  for (const uid of ['rotate-owner', 'rotate-child', 'rotate-outsider', 'rotate-joiner']) {
    await db.doc(`users/${uid}`).set({ uid, role: 'child', displayName: uid, circleId: null });
  }
  family = await handlers.createCircle.run(request('rotate-owner', { circleName: 'Rotation family' }));
  await handlers.joinCircle.run(request('rotate-child', { inviteCode: family.childInviteCode }));
});
after(async () => { await Promise.all(getApps().map(deleteApp)); });
const rotate = (uid) => handlers.rotateCircleInvites.run(request(uid, { circleId: family.id }));

test('only authenticated parents of the circle can rotate invites', async () => {
  await assert.rejects(rotate(null), { code: 'unauthenticated' });
  await assert.rejects(rotate('rotate-child'), { code: 'permission-denied' });
  await assert.rejects(rotate('rotate-outsider'), { code: 'permission-denied' });
});
test('rotation atomically replaces both codes and invalidates old secrets', async () => {
  const result = await rotate('rotate-owner');
  replacement = (await db.doc(`circles/${family.id}/private/invites`).get()).data();
  assert.notEqual(replacement.parentInviteCode, family.parentInviteCode);
  assert.notEqual(replacement.childInviteCode, family.childInviteCode);
  assert.equal((await db.doc(`circleInvites/${inviteKey(family.parentInviteCode)}`).get()).exists, false);
  assert.equal((await db.doc(`circleInvites/${inviteKey(family.childInviteCode)}`).get()).exists, false);
  assert.ok(Date.parse(result.expiresAt) > Date.now() + 6 * 86400000);
  const circle = (await db.doc(`circles/${family.id}`).get()).data();
  assert.deepEqual(circle.memberIds.sort(), ['rotate-child', 'rotate-owner']);
  assert.equal(circle.childInviteCode, undefined);
  assert.equal(circle.parentInviteCode, undefined);
});
test('old code rejects new members while replacement assigns its intended role', async () => {
  await assert.rejects(handlers.joinCircle.run(request('rotate-joiner', { inviteCode: family.childInviteCode })), { code: 'not-found' });
  const joined = await handlers.joinCircle.run(request('rotate-joiner', { inviteCode: replacement.childInviteCode }));
  assert.equal(joined.role, 'child');
  assert.equal(joined.circleId, family.id);
  assert.equal((await db.doc('users/rotate-child').get()).data().circleId, family.id);
});
test('successive rotation leaves only the latest pair redeemable', async () => {
  const previous = replacement;
  await rotate('rotate-owner');
  const latest = (await db.doc(`circles/${family.id}/private/invites`).get()).data();
  for (const code of [previous.parentInviteCode, previous.childInviteCode]) {
    assert.equal((await db.doc(`circleInvites/${inviteKey(code)}`).get()).exists, false);
  }
  for (const code of [latest.parentInviteCode, latest.childInviteCode]) {
    assert.equal((await db.doc(`circleInvites/${inviteKey(code)}`).get()).exists, true);
  }
});
