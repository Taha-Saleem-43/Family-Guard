const { randomBytes, createHash } = require('node:crypto');

function normalizeInvite(value) {
  if (typeof value !== 'string') throw new Error('Enter a valid invite code.');
  const code = value.trim().toUpperCase();
  if (!/^(FAMILY|PARENT)-[A-F0-9]{16}$/.test(code)) {
    throw new Error('Enter the complete invite code shared by a parent.');
  }
  return code;
}

function newInvite(role) {
  return `${role === 'parent' ? 'PARENT' : 'FAMILY'}-${randomBytes(8).toString('hex').toUpperCase()}`;
}

function inviteKey(code) {
  return createHash('sha256').update(code).digest('hex');
}

function circleName(value) {
  if (typeof value !== 'string' || value.trim().length < 2 || value.trim().length > 60) {
    throw new Error('Circle name must contain 2–60 characters.');
  }
  return value.trim();
}

module.exports = { normalizeInvite, newInvite, inviteKey, circleName };
