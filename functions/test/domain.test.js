const test = require('node:test');
const assert = require('node:assert/strict');
const { newInvite, normalizeInvite, inviteKey, circleName } = require('../domain');

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
