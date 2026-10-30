const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { newInvite, inviteKey } = require('../domain');
const { authenticated } = require('../auth');

function createCircleManagementHandlers(db) {
  return {
    async leave(request) {
      const uid = authenticated(request);
      const { circleId, successorId } = request.data || {};
      const validId = (id) => typeof id === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(id);
      if (request.data?.expectedUid !== uid || !validId(circleId) ||
          (successorId != null && (!validId(successorId) || successorId === uid))) {
        throw new HttpsError('invalid-argument', 'Select your circle and a different co-parent.');
      }
      const parentInviteCode = newInvite('parent'), childInviteCode = newInvite('child');
      return db.runTransaction(async (tx) => {
        const profile = db.doc(`users/${uid}`), circle = db.doc(`circles/${circleId}`);
        const invites = circle.collection('private').doc('invites');
        const [user, family, oldInvites, deletion] = await Promise.all([
          tx.get(profile), tx.get(circle), tx.get(invites), tx.get(db.doc(`accountDeletions/${uid}`)),
        ]);
        if (!user.exists || user.data().deletionRequested || deletion.exists) {
          throw new HttpsError('failed-precondition', 'Your account is unavailable.');
        }
        // A lost response may be retried, but must never detach a later circle.
        if (!user.data().circleId) return { left: true };
        const activeId = user.data().activeSosId;
        const activeAlert = validId(activeId) ? await tx.get(db.doc(`sos_alerts/${activeId}`)) : null;
        if (user.data().isSosActive || activeAlert?.data()?.status === 'active') {
          throw new HttpsError('failed-precondition', 'Resolve your active SOS before leaving the circle.');
        }
        const ids = family.data()?.memberIds;
        if (user.data().circleId !== circleId || !family.exists || !Array.isArray(ids) ||
            ids.length > 20 || ids.some((id) => !validId(id)) || !ids.includes(uid)) {
          throw new HttpsError('permission-denied', 'Your circle membership changed.');
        }
        const remaining = [...new Set(ids.filter((id) => id !== uid))];
        const peers = remaining.length ? await tx.getAll(...remaining.map((id) => db.doc(`users/${id}`))) : [];
        const parents = peers.filter((peer) => peer.exists && peer.data().circleId === circleId &&
          peer.data().role === 'parent' && !peer.data().deletionRequested);
        if (remaining.length && user.data().role === 'parent' &&
            !parents.some((parent) => parent.id === successorId)) {
          throw new HttpsError('failed-precondition', 'Invite another parent first, then select that co-parent before leaving.');
        }
        if (user.data().role !== 'parent' && successorId != null) {
          throw new HttpsError('permission-denied', 'Only a parent can hand over responsibility.');
        }
        // A sole member can close the circle. Saved places have a server-owned cap of 50.
        const places = !remaining.length
          ? await tx.get(db.collection('places').where('circleId', '==', circleId).limit(51)) : null;
        if (places?.size > 50) throw new HttpsError('failed-precondition', 'Contact support to close this circle.');
        // All reads precede writes; concurrent departures re-evaluate the last-parent guard.
        for (const code of [oldInvites.data()?.parentInviteCode, oldInvites.data()?.childInviteCode]) {
          if (typeof code === 'string' && code) tx.delete(db.doc(`circleInvites/${inviteKey(code)}`));
        }
        if (!remaining.length) {
          for (const place of places.docs) tx.delete(place.ref);
          tx.delete(circle.collection('private').doc('places'));
          tx.delete(invites);
          tx.delete(circle);
        } else {
          const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 86400000);
          for (const [code, role] of [[parentInviteCode, 'parent'], [childInviteCode, 'child']]) {
            tx.create(db.doc(`circleInvites/${inviteKey(code)}`), { circleId, role, expiresAt, revoked: false });
          }
          tx.set(invites, { parentInviteCode, childInviteCode, expiresAt });
          tx.update(circle, { memberIds: remaining, requiresParent: parents.length === 0,
            ...(family.data().createdBy === uid ? { createdBy: successorId || parents[0]?.id || '' } : {}) });
        }
        tx.update(profile, { circleId: null, role: 'child', isSosActive: false, activeSosId: null,
          ...Object.fromEntries(['latitude', 'longitude', 'speedMph', 'movementActivity', 'lastSeen',
            'lastLocationCapturedAt', 'lastLocationPointId', 'batteryLevel', 'isCharging']
            .map((field) => [field, FieldValue.delete()])) });
        tx.delete(db.doc(`locations/${uid}`));
        return { left: true, closed: remaining.length === 0 };
      });
    },
    async rotateInvites(request) {
      const uid = authenticated(request);
      const circleId = request.data?.circleId;
      if (typeof circleId !== 'string' || !circleId || circleId.includes('/')) {
        throw new HttpsError('invalid-argument', 'Select your family circle first.');
      }
      const parentInviteCode = newInvite('parent');
      const childInviteCode = newInvite('child');
      return db.runTransaction(async (tx) => {
        const circle = db.doc(`circles/${circleId}`);
        const privateInvites = circle.collection('private').doc('invites');
        const [profile, family, oldInvites] = await Promise.all([
          tx.get(db.doc(`users/${uid}`)), tx.get(circle), tx.get(privateInvites),
        ]);
        if (!profile.exists || profile.data().deletionRequested || profile.data().role !== 'parent' ||
            profile.data().circleId !== circleId || !family.exists ||
            !family.data().memberIds?.includes(uid)) {
          throw new HttpsError('permission-denied', 'Only a parent in this circle can replace invite codes.');
        }
        const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 86400000);
        for (const oldCode of [oldInvites.data()?.parentInviteCode, oldInvites.data()?.childInviteCode]) {
          if (typeof oldCode === 'string' && oldCode) {
            tx.delete(db.doc(`circleInvites/${inviteKey(oldCode)}`));
          }
        }
        for (const [code, role] of [[parentInviteCode, 'parent'], [childInviteCode, 'child']]) {
          tx.create(db.doc(`circleInvites/${inviteKey(code)}`), { circleId, role, expiresAt, revoked: false });
        }
        tx.set(privateInvites, { parentInviteCode, childInviteCode, expiresAt });
        return { expiresAt: expiresAt.toDate().toISOString() };
      });
    },
  };
}
module.exports = { createCircleManagementHandlers };
