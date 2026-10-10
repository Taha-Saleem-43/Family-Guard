const { createHash } = require('node:crypto');
const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { authenticated } = require('../auth');

function requestId(value) {
  if (typeof value !== 'string' || !/^[a-f0-9]{32}$/.test(value)) {
    throw new HttpsError('invalid-argument', 'A valid emergency request ID is required.');
  }
  return value;
}

function coordinates(data) {
  const latitude = data.latitude ?? null;
  const longitude = data.longitude ?? null;
  if (latitude === null && longitude === null) return { latitude, longitude };
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpsError('invalid-argument', 'Emergency coordinates are invalid.');
  }
  return { latitude, longitude };
}

function summary(snapshot) {
  const data = snapshot.data();
  return { alertId: snapshot.id, status: data.status, timestamp: data.timestamp };
}

function createSOSHandlers(db) {
  return {
    async trigger(request) {
      const uid = authenticated(request);
      const data = request.data ?? {};
      const id = requestId(data.requestId);
      const location = coordinates(data);
      if (typeof data.circleId !== 'string' || !data.circleId || data.circleId.includes('/')) {
        throw new HttpsError('invalid-argument', 'Select your family circle first.');
      }
      const address = data.address ?? 'Location unavailable';
      if (typeof address !== 'string' || address.length > 200) {
        throw new HttpsError('invalid-argument', 'Emergency address is too long.');
      }
      const alertId = createHash('sha256').update(`${uid}:${id}`).digest('hex');
      const alert = db.doc(`sos_alerts/${alertId}`);
      const profile = db.doc(`users/${uid}`);
      return db.runTransaction(async (tx) => {
        const [user, existing, circle] = await Promise.all([
          tx.get(profile), tx.get(alert), tx.get(db.doc(`circles/${data.circleId}`)),
        ]);
        if (!user.exists || user.data().deletionRequested || user.data().circleId !== data.circleId ||
            !circle.exists || !circle.data().memberIds?.includes(uid)) {
          throw new HttpsError('permission-denied', 'You must belong to this family circle.');
        }
        // A timeout retry always returns the original result, including after resolution.
        if (existing.exists) {
          if (existing.data().circleId !== data.circleId) {
            throw new HttpsError('failed-precondition', 'This request belongs to another circle.');
          }
          return summary(existing);
        }
        const activeId = user.data().activeSosId;
        if (typeof activeId === 'string' && activeId && !activeId.includes('/')) {
          const active = await tx.get(db.doc(`sos_alerts/${activeId}`));
          if (active.exists && active.data().status === 'active') {
            if (active.data().senderId !== uid || active.data().circleId !== data.circleId) {
              throw new HttpsError('failed-precondition', 'Existing emergency needs support review.');
            }
            return summary(active);
          }
        }
        const now = Timestamp.now();
        const timestamp = now.toDate().toISOString();
        tx.create(alert, {
          circleId: data.circleId, senderId: uid,
          senderName: typeof user.data().displayName === 'string'
            ? user.data().displayName.trim().slice(0, 80) || 'Family member'
            : 'Family member',
          ...location, address, timestamp, status: 'active', pushFanoutPending: true,
          resolvedAt: null, resolvedBy: null, durationSeconds: 0,
        });
        tx.update(profile, { isSosActive: true, activeSosId: alertId, lastSosAt: timestamp });
        return { alertId, status: 'active', timestamp };
      });
    },

    async resolve(request) {
      const uid = authenticated(request);
      const alertId = request.data?.alertId;
      // Existing pre-release Firestore auto IDs remain resolvable during migration.
      if (typeof alertId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(alertId)) {
        throw new HttpsError('invalid-argument', 'A valid emergency ID is required.');
      }
      return db.runTransaction(async (tx) => {
        const alertRef = db.doc(`sos_alerts/${alertId}`);
        const profile = db.doc(`users/${uid}`);
        const [alert, user] = await Promise.all([tx.get(alertRef), tx.get(profile)]);
        if (!alert.exists || alert.data().senderId !== uid || !user.exists || user.data().deletionRequested ||
            alert.data().circleId !== user.data().circleId) {
          throw new HttpsError('permission-denied', 'Only the sender can resolve this emergency.');
        }
        if (alert.data().status === 'resolved') return { resolved: true, alertId };
        if (alert.data().status !== 'active') {
          throw new HttpsError('failed-precondition', 'Emergency status is invalid.');
        }
        const now = Date.now();
        const start = Date.parse(alert.data().timestamp);
        tx.update(alertRef, { status: 'resolved', resolvedBy: uid, pushFanoutPending: false,
          resolvedAt: new Date(now).toISOString(),
          durationSeconds: Number.isFinite(start) ? Math.max(0, Math.floor((now - start) / 1000)) : 0,
          expireAt: Timestamp.fromMillis(now + 30 * 86400000),
        });
        // Resolving an old alert must never erase a newer emergency pointer.
        if (user.data().activeSosId === alertId) {
          tx.update(profile, { isSosActive: false, activeSosId: null });
        }
        return { resolved: true, alertId };
      });
    },
  };
}

module.exports = { createSOSHandlers };
