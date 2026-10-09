const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeInvite, newInvite, inviteKey, circleName } = require('./domain');
const { authenticated } = require('./auth');

initializeApp();
const db = getFirestore();
// Clients must register App Check before release; emulator uses debug tokens.
const options = { region: 'us-central1', enforceAppCheck: true, maxInstances: 10 };
const sos = require('./features/sos').createSOSHandlers(db);
const locations = require('./features/locations').createLocationHandlers(db);
exports.ingestLocations = onCall(options, locations.ingest);
const places = require('./features/places').createPlaceHandlers(db);
exports.savePlace = onCall(options, places.save);
exports.deletePlace = onCall(options, places.remove);
exports.togglePlaceNotifications = onCall(options, places.toggle);
exports.triggerSos = onCall(options, sos.trigger);
exports.resolveSos = onCall(options, sos.resolve);
const circles = require('./features/circles').createCircleManagementHandlers(db);
exports.rotateCircleInvites = onCall(options, circles.rotateInvites);
const accounts = require('./features/accounts').createAccountDeletionHandlers(db, getAuth());
exports.requestAccountDeletion = onCall(options, accounts.request);
exports.processAccountDeletion = onDocumentCreated({ document: 'accountDeletions/{uid}',
  region: options.region, retry: true, timeoutSeconds: 540, concurrency: 1, maxInstances: 5,
}, (event) => accounts.process(event.params.uid));
exports.retryAccountDeletions = onSchedule({ schedule: 'every 60 minutes', region: options.region,
  timeoutSeconds: 540, maxInstances: 1 }, () => accounts.retryPending());
const push = require('./features/push').createPushHandlers(db, getMessaging());
exports.registerPushDevice = onCall(options, push.register);
exports.unregisterPushDevice = onCall(options, push.unregister);
exports.acknowledgeSosPush = onCall(options, push.acknowledge);
exports.enqueueSosPush = onDocumentCreated({ document: 'sos_alerts/{alertId}', region: options.region,
  retry: true, timeoutSeconds: 120, maxInstances: 5 }, (event) => push.enqueue(event.params.alertId));
exports.deliverSosPush = onDocumentCreated({ document: 'sosPushDeliveries/{deliveryId}', region: options.region,
  retry: true, timeoutSeconds: 120, maxInstances: 10 }, (event) => push.process(event.params.deliveryId));
exports.retrySosPushDeliveries = onSchedule({ schedule: 'every 1 minutes', region: options.region,
  timeoutSeconds: 120, maxInstances: 1 }, () => push.retryPending());
const placePush = require('./features/push').createPushHandlers(db, getMessaging(), 'place');
exports.acknowledgePlacePush = onCall(options, placePush.acknowledge);
exports.enqueuePlacePush = onDocumentCreated({ document: 'placeEvents/{eventId}', region: options.region,
  retry: true, timeoutSeconds: 120, maxInstances: 5 }, (event) => placePush.enqueue(event.params.eventId));
exports.deliverPlacePush = onDocumentCreated({ document: 'placePushDeliveries/{deliveryId}', region: options.region,
  retry: true, timeoutSeconds: 120, maxInstances: 10 }, (event) => placePush.process(event.params.deliveryId));
exports.retryPlacePushDeliveries = onSchedule({ schedule: 'every 1 minutes', region: options.region,
  timeoutSeconds: 120, maxInstances: 1 }, () => placePush.retryPending());

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
    if (user.data().deletionRequested) throw new HttpsError('failed-precondition', 'Your account is being deleted.');
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
    const [snapshot, profile, deletion] = await Promise.all([
      tx.get(attempts), tx.get(db.doc(`users/${uid}`)), tx.get(db.doc(`accountDeletions/${uid}`)),
    ]);
    if (!profile.exists || profile.data().deletionRequested || deletion.exists) {
      throw new HttpsError('failed-precondition', 'Your account is unavailable or being deleted.');
    }
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
    if (user.data().deletionRequested) throw new HttpsError('failed-precondition', 'Your account is being deleted.');
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
    tx.update(circle, { memberIds: FieldValue.arrayUnion(uid),
      ...(role === 'parent' ? { requiresParent: false } : {}) });
    return { circleId: data.circleId, role };
  });
});
