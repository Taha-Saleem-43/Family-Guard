const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { randomUUID } = require('node:crypto');

function createAccountDeletionHandlers(db, auth) {
  const jobRef = (uid) => db.doc(`accountDeletions/${uid}`);
  async function deleteQuery(query) {
    while (true) {
      const page = await query.limit(200).get();
      if (page.empty) return;
      const batch = db.batch();
      for (const doc of page.docs) batch.delete(doc.ref);
      await batch.commit();
    }
  }
  async function authOperation(operation) {
    try { await operation(); } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
  }
  return {
    async request(request) {
      const uid = request.auth?.uid;
      if (!uid) throw new HttpsError('unauthenticated', 'Please sign in first.');
      if (request.data?.expectedUid !== uid) {
        throw new HttpsError('failed-precondition', 'Your account changed. Please try again.');
      }
      return db.runTransaction(async (tx) => {
        const job = await tx.get(jobRef(uid));
        if (job.exists) return { accepted: true };
        const age = Date.now() / 1000 - request.auth.token?.auth_time;
        if (!Number.isFinite(age) || age < -30 || age > 300) {
          throw new HttpsError('failed-precondition', 'Verify your sign-in again before deleting your account.');
        }
        const profile = db.doc(`users/${uid}`);
        const user = await tx.get(profile);
        const circleId = user.data()?.circleId;
        let closedCircleId = null;
        let family;
        let circle;
        let remaining = [];
        let peers = [];
        if (typeof circleId === 'string' && circleId && !circleId.includes('/')) {
          circle = db.doc(`circles/${circleId}`);
          family = await tx.get(circle);
          if (family.exists) {
            const ids = family.data().memberIds;
            if (!Array.isArray(ids) || ids.length > 20 || ids.some((id) => typeof id !== 'string' || !id || id.includes('/'))) {
              throw new HttpsError('failed-precondition', 'Circle membership needs support review before deletion.');
            }
            remaining = [...new Set(ids.filter((id) => id !== uid))];
            if (remaining.length) peers = await tx.getAll(...remaining.map((id) => db.doc(`users/${id}`)));
            else closedCircleId = circleId;
          }
        }
        // All reads precede writes. Membership detachment and the tombstone are atomic.
        if (family?.exists) {
          if (closedCircleId) tx.delete(circle);
          else {
            const nextParent = peers.find((peer) => peer.exists && peer.data().circleId === circleId &&
              peer.data().role === 'parent' && !peer.data().deletionRequested);
            const update = { memberIds: remaining, requiresParent: !nextParent };
            if (family.data().createdBy === uid) update.createdBy = nextParent?.id ?? '';
            tx.update(circle, update);
          }
        }
        if (user.exists) tx.update(profile, { deletionRequested: true, circleId: null, role: 'child' });
        tx.create(jobRef(uid), { status: 'pending', requestedAt: Timestamp.now(), closedCircleId,
          leaseUntil: Timestamp.fromMillis(0) });
        return { accepted: true };
      });
    },
    async process(uid) {
      const ref = jobRef(uid);
      const leaseOwner = randomUUID();
      const job = await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(ref);
        const data = snapshot.data();
        if (!data || data.status === 'complete' ||
            (data.status === 'processing' && data.leaseUntil?.toMillis() > Date.now())) return null;
        tx.update(ref, { status: 'processing', updatedAt: Timestamp.now(), leaseOwner,
          leaseUntil: Timestamp.fromMillis(Date.now() + 10 * 60000), attempts: FieldValue.increment(1) });
        return data;
      });
      if (!job) return;
      async function finish(fields) {
        await db.runTransaction(async (tx) => {
          const current = await tx.get(ref);
          if (current.data()?.leaseOwner !== leaseOwner || current.data()?.status === 'complete') return;
          tx.update(ref, { ...fields, leaseOwner: FieldValue.delete(), leaseUntil: Timestamp.fromMillis(0) });
        });
      }
      try {
        await authOperation(() => auth.updateUser(uid, { disabled: true }));
        await db.recursiveDelete(db.doc(`locationHistory/${uid}`));
        await db.doc(`locations/${uid}`).delete();
        await deleteQuery(db.collection('sos_alerts').where('senderId', '==', uid));
        await deleteQuery(db.collection('places').where('createdBy', '==', uid));
        await deleteQuery(db.collection('pushDevices').where('uid', '==', uid));
        await deleteQuery(db.collection('sosPushDeliveries').where('recipientUid', '==', uid));
        for (const collection of ['placeEvents', 'sosEvents']) {
          for (const field of ['userId', 'uid', 'memberId', 'senderId']) {
            await deleteQuery(db.collection(collection).where(field, '==', uid));
          }
        }
        await db.doc(`inviteAttempts/${uid}`).delete();
        while (true) {
          const circles = await db.collection('circles').where('createdBy', '==', uid).limit(200).get();
          if (circles.empty) break;
          const batch = db.batch();
          for (const circle of circles.docs) batch.update(circle.ref, { createdBy: '' });
          await batch.commit();
        }
        const closedCircleId = job.closedCircleId;
        if (closedCircleId) {
          await db.recursiveDelete(db.doc(`circles/${closedCircleId}`));
          await deleteQuery(db.collection('circleInvites').where('circleId', '==', closedCircleId));
          for (const collection of ['places', 'placeEvents', 'sosEvents', 'sos_alerts']) {
            await deleteQuery(db.collection(collection).where('circleId', '==', closedCircleId));
          }
        }
        await db.doc(`users/${uid}`).delete();
        await authOperation(() => auth.deleteUser(uid));
        await finish({ status: 'complete', completedAt: Timestamp.now(),
          expireAt: Timestamp.fromMillis(Date.now() + 2 * 86400000), lastErrorCode: FieldValue.delete() });
      } catch (error) {
        await finish({ status: 'pending', updatedAt: Timestamp.now(),
          lastErrorCode: typeof error.code === 'string' ? error.code.slice(0, 80) : 'internal' });
        throw error;
      }
    },
    async retryPending() {
      const [pending, stalled] = await Promise.all([
        db.collection('accountDeletions').where('status', '==', 'pending').limit(10).get(),
        db.collection('accountDeletions').where('status', '==', 'processing')
          .where('leaseUntil', '<=', Timestamp.now()).limit(10).get(),
      ]);
      for (const job of [...pending.docs, ...stalled.docs]) {
        try { await this.process(job.id); } catch (error) {
          console.error('Account deletion retry failed', { jobId: job.id, code: error.code ?? 'internal' });
        }
      }
    },
  };
}
module.exports = { createAccountDeletionHandlers };
