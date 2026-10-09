const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeInvite, newInvite, inviteKey, circleName } = require('./domain');

initializeApp();
const db = getFirestore();
// Clients must register App Check before release; emulator uses debug tokens.
const options = { region: 'us-central1', enforceAppCheck: true, maxInstances: 10 };
const sos = require('./features/sos').createSOSHandlers(db);
exports.triggerSos = onCall(options, sos.trigger);
exports.resolveSos = onCall(options, sos.resolve);

function authenticated(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in first.');
  return request.auth.uid;
}

function validate(fn, value) {
  try { return fn(value); } catch (error) {
    throw new HttpsError('invalid-argument', error.message);
  }
}

exports.createCircle = onCall(options, async (request) => {
  const uid = authenticated(request);
  const name = validate(circleName, request.data?.circleName);
  const circle = db.collection('circles').doc();
  const profile = db.collection('users').doc(uid);
  const parentCode = newInvite('parent');
  const childCode = newInvite('child');
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + 7 * 86400000);
  const result = {
    id: circle.id, name, createdBy: uid, memberIds: [uid],
    createdAt: now.toDate().toISOString(),
    parentInviteCode: parentCode, childInviteCode: childCode,
  };
  await db.runTransaction(async (tx) => {
    const user = await tx.get(profile);
    if (!user.exists) throw new HttpsError('failed-precondition', 'Finish account setup first.');
    if (user.data().circleId) throw new HttpsError('already-exists', 'You already belong to a circle.');
    // Invite secrets are never stored in the circle document readable by children.
    const { parentInviteCode, childInviteCode, ...publicCircle } = result;
    tx.create(circle, publicCircle);
    tx.create(circle.collection('private').doc('invites'), {
      parentInviteCode, childInviteCode, expiresAt,
    });
    for (const [code, role] of [[parentCode, 'parent'], [childCode, 'child']]) {
      tx.create(db.collection('circleInvites').doc(inviteKey(code)), {
        circleId: circle.id, role, expiresAt, revoked: false,
      });
    }
    tx.update(profile, { circleId: circle.id, role: 'parent' });
  });
  return result;
});

exports.joinCircle = onCall(options, async (request) => {
  const uid = authenticated(request);
  const code = validate(normalizeInvite, request.data?.inviteCode);
  // Persist rate-limit accounting separately: failed redemptions must also count.
  const attempts = db.collection('inviteAttempts').doc(uid);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(attempts);
    const data = snapshot.data();
    const now = Date.now();
    const sameWindow = data && now - data.windowStart.toMillis() < 3600000;
    if (sameWindow && data.count >= 10) {
      throw new HttpsError('resource-exhausted', 'Too many attempts. Try again in an hour.');
    }
    tx.set(attempts, {
      count: sameWindow ? data.count + 1 : 1,
      windowStart: sameWindow ? data.windowStart : Timestamp.fromMillis(now),
      expireAt: Timestamp.fromMillis(now + 86400000),
    });
  });
  return db.runTransaction(async (tx) => {
    const profile = db.collection('users').doc(uid);
    const [user, invite] = await Promise.all([
      tx.get(profile), tx.get(db.collection('circleInvites').doc(inviteKey(code))),
    ]);
    if (!user.exists) throw new HttpsError('failed-precondition', 'Finish account setup first.');
    const data = invite.data();
    if (!data || data.revoked || data.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('not-found', 'This invite is invalid or expired. Ask a parent for a new code.');
    }
    if (user.data().circleId && user.data().circleId !== data.circleId) {
      throw new HttpsError('failed-precondition', 'You already belong to another circle.');
    }
    const circle = db.collection('circles').doc(data.circleId);
    const circleSnapshot = await tx.get(circle);
    if (!circleSnapshot.exists) throw new HttpsError('not-found', 'Circle no longer exists.');
    const members = circleSnapshot.data().memberIds || [];
    if (!members.includes(uid) && members.length >= 20) {
      throw new HttpsError('resource-exhausted', 'This circle has reached its member limit.');
    }
    // An existing member cannot change role by redeeming a second invite.
    const role = user.data().circleId ? user.data().role : data.role;
    tx.update(profile, { circleId: data.circleId, role });
    tx.update(circle, { memberIds: FieldValue.arrayUnion(uid) });
    return { circleId: data.circleId, role };
  });
});
