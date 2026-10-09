const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { authenticated } = require('../auth');
const { createHash } = require('node:crypto');

function validateFix(value, now) {
  if (!value || typeof value.id !== 'string' || !/^[a-f0-9]{64}$/.test(value.id)
    || !Number.isSafeInteger(value.capturedAt)
    || value.capturedAt < now - 7 * 86400000 || value.capturedAt > now + 30000
    || !Number.isFinite(value.latitude) || Math.abs(value.latitude) > 90
    || !Number.isFinite(value.longitude) || Math.abs(value.longitude) > 180
    || !Number.isFinite(value.speedMph) || value.speedMph < 0 || value.speedMph > 1000
    || !['stationary', 'walking', 'driving'].includes(value.movementActivity)
    || !Number.isInteger(value.batteryLevel) || value.batteryLevel < -1 || value.batteryLevel > 100
    || typeof value.isCharging !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Invalid or expired location fix.');
  }
  return { id: value.id, capturedAt: value.capturedAt, latitude: value.latitude,
    longitude: value.longitude, speedMph: value.speedMph, movementActivity: value.movementActivity,
    batteryLevel: value.batteryLevel, isCharging: value.isCharging };
}

function createLocationHandlers(db) {
  const places = require('./places').createPlaceHandlers(db);
  async function ingest(request) {
    const uid = authenticated(request);
    const { circleId, fixes, sharingStartedAt } = request.data || {};
    const now = Date.now();
    const authTime = request.auth?.token?.auth_time;
    if (!Number.isSafeInteger(authTime) || authTime <= 0) throw new HttpsError('unauthenticated', 'Sign in again before sharing.');
    if (!Number.isSafeInteger(sharingStartedAt) || sharingStartedAt < authTime * 1000
      || sharingStartedAt > now + 30000) throw new HttpsError('failed-precondition', 'Sharing belongs to an earlier sign-in. Reopen the app to renew it.');
    if (typeof circleId !== 'string' || !circleId || circleId.length > 128
      || circleId.includes('/') || !Array.isArray(fixes) || fixes.length < 1 || fixes.length > 50) {
      throw new HttpsError('invalid-argument', 'Provide a circle and up to 50 fixes.');
    }
    const points = fixes.map((fix) => validateFix(fix, now));
    if (points.some((point) => point.capturedAt < sharingStartedAt)) throw new HttpsError('invalid-argument', 'Fix predates the sharing session.');
    if (new Set(points.map((point) => point.id)).size !== points.length) {
      throw new HttpsError('invalid-argument', 'Duplicate fix IDs in batch.');
    }
    const profileRef = db.doc(`users/${uid}`);
    return db.runTransaction(async (tx) => {
      const [profile, circle, deletion] = await tx.getAll(
        profileRef, db.doc(`circles/${circleId}`), db.doc(`accountDeletions/${uid}`));
      const user = profile.data();
      if (!user || user.deletionRequested || deletion.exists || user.circleId !== circleId
        || user.role !== 'child' || !circle.exists || !circle.data().memberIds?.includes(uid)) {
        throw new HttpsError('failed-precondition', 'Location sharing context is no longer active.');
      }
      const windowStart = user.locationIngestWindow?.toMillis?.() || 0;
      const sameWindow = now >= windowStart && now - windowStart < 60000;
      const count = sameWindow && Number.isInteger(user.locationIngestCount) ? user.locationIngestCount : 0;
      if (count + points.length > 600) throw new HttpsError('resource-exhausted', 'Location recovery is temporarily rate limited.');
      const refs = points.map((point) => db.doc(`locationHistory/${uid}/points/${point.id}`));
      const existing = await tx.getAll(...refs);
      let newest = null;
      const watermark = user.lastLocationCapturedAt?.toMillis?.()
        ?? (Date.parse(user.lastSeen || '') || 0);
      const pending = [];
      for (let index = 0; index < points.length; index++) {
        const point = points[index];
        const { id, capturedAt, ...fields } = point;
        const fingerprint = createHash('sha256').update(JSON.stringify({ circleId, ...point })).digest('hex');
        if (existing[index].exists) {
          if (existing[index].data().fingerprint !== fingerprint) {
            throw new HttpsError('already-exists', 'Fix ID was already used for a different location.');
          }
          continue;
        }
        pending.push({ ref: refs[index], fields: { ...fields, circleId, fingerprint,
          timestamp: Timestamp.fromMillis(capturedAt), expireAt: Timestamp.fromMillis(capturedAt + 30 * 86400000) } });
        if (capturedAt > watermark && capturedAt >= now - 120000
          && (!newest || capturedAt > newest.capturedAt || (capturedAt === newest.capturedAt && id > newest.id))) {
          newest = point;
        }
      }
      await places.recordTransitions(tx, uid, circleId, user, newest);
      for (const point of pending) tx.create(point.ref, point.fields);
      const profileUpdate = { locationIngestWindow: Timestamp.fromMillis(sameWindow ? windowStart : now),
        locationIngestCount: count + points.length };
      if (newest) {
        const { id, capturedAt, ...fields } = newest;
        Object.assign(profileUpdate, { ...fields, lastSeen: new Date(capturedAt).toISOString(),
          lastLocationCapturedAt: Timestamp.fromMillis(capturedAt), lastLocationPointId: id });
      }
      tx.update(profileRef, profileUpdate);
      return { acceptedIds: points.map((point) => point.id), liveUpdated: newest !== null };
    });
  }
  return { ingest };
}
module.exports = { createLocationHandlers, validateFix };
