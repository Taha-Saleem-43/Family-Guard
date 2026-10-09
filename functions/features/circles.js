const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { newInvite, inviteKey } = require('../domain');

function createCircleManagementHandlers(db) {
  return {
    async rotateInvites(request) {
      const uid = request.auth?.uid;
      if (!uid) throw new HttpsError('unauthenticated', 'Please sign in first.');
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
        if (!profile.exists || profile.data().role !== 'parent' ||
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
