const test = require('node:test');
const assert = require('node:assert/strict');
const { newInvite, normalizeInvite, inviteKey, circleName } = require('../domain');
const { authenticated } = require('../auth');

test('account fence rejects changed SDK identity before any mutation', () => {
  assert.throws(() => authenticated({ auth: null }), { code: 'unauthenticated' });
  assert.throws(() => authenticated({ auth: { uid: 'new' }, data: { expectedUid: 'old' } }), { code: 'failed-precondition' });
  assert.equal(authenticated({ auth: { uid: 'same' }, data: { expectedUid: 'same' } }), 'same');
  assert.equal(authenticated({ auth: { uid: 'legacy' }, data: {} }), 'legacy');
});

test('invites normalize and have independent cryptographic identifiers', () => {
  const a = newInvite('child');
  const b = newInvite('parent');
  assert.match(a, /^FAMILY-[A-F0-9]{16}$/);
  assert.match(b, /^PARENT-[A-F0-9]{16}$/);
  assert.equal(normalizeInvite(` ${a.toLowerCase()} `), a);
  assert.equal(inviteKey(a).length, 64);
  assert.notEqual(inviteKey(a), inviteKey(b));
});
test('invalid, short and prefix-only invites are rejected', () => {
  for (const code of ['', 'PARENT', 'PARENT-XXXX', null, {}, 'FAMILY-000000000000000G']) {
    assert.throws(() => normalizeInvite(code));
  }
});
test('circle names are bounded and trimmed', () => {
  assert.equal(circleName('  My family  '), 'My family');
  for (const name of ['', 'x', 'x'.repeat(61), null]) assert.throws(() => circleName(name));
});

const { validateFix } = require('../features/locations');
test('accuracy is optional for old clients and bounded for new clients', () => {
  const now = Date.now();
  const fix = { id: 'a'.repeat(64), capturedAt: now, latitude: 33, longitude: 73,
    speedMph: 0, movementActivity: 'stationary', batteryLevel: 80, isCharging: false };
  assert.equal(validateFix(fix, now).accuracyMeters, undefined);
  assert.equal(validateFix({ ...fix, accuracyMeters: 12.5 }, now).accuracyMeters, 12.5);
  for (const accuracyMeters of [null, -1, 101, NaN, Infinity, '10']) {
    assert.throws(() => validateFix({ ...fix, accuracyMeters }, now), { code: 'invalid-argument' });
  }
});
