const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { authenticated } = require('../auth');
const { createHash } = require('node:crypto');
const hash = (value) => createHash('sha256').update(value).digest('hex');
const validId = (id) => typeof id === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(id)
  && !['__proto__', 'constructor', 'prototype'].includes(id);
function distance(a, b) {
  const radians = Math.PI / 180;
  const dLat = (a.latitude - b.latitude) * radians, dLng = (a.longitude - b.longitude) * radians;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.latitude * radians) * Math.cos(b.latitude * radians) * Math.sin(dLng / 2) ** 2;
  return 12742000 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, h))));
}
function validatePlace(data) {
  if (!data || typeof data.name !== 'string' || !data.name.trim() || data.name.trim().length > 80
    || typeof data.address !== 'string' || data.address.length > 240
    || !['home', 'school', 'work', 'custom'].includes(data.category)
    || !Number.isFinite(data.latitude) || Math.abs(data.latitude) > 90
    || !Number.isFinite(data.longitude) || Math.abs(data.longitude) > 180
    || !Number.isFinite(data.radius) || data.radius < 100 || data.radius > 1000
    || !Number.isInteger(data.colorValue) || data.colorValue < 0 || data.colorValue > 0xffffffff
    || typeof data.notifyArrive !== 'boolean' || typeof data.notifyLeave !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Invalid saved place.');
  }
  const { address, category, latitude, longitude, radius, colorValue, notifyArrive, notifyLeave } = data;
  return { name: data.name.trim(), address, category, latitude, longitude, radius, colorValue, notifyArrive, notifyLeave };
}
function createPlaceHandlers(db) {
  async function loadConfig(tx, circleId, suppliedSnapshot) {
    const ref = db.doc(`circles/${circleId}/private/places`);
    const snapshot = suppliedSnapshot || await tx.get(ref);
    if (snapshot.exists) return { ref, places: snapshot.data().places || {}, missing: false };
    // Bootstrap old development circles once. Future changes are callable-owned.
    const legacy = await tx.get(db.collection('places').where('circleId', '==', circleId).limit(51));
    if (legacy.size > 50) throw new HttpsError('resource-exhausted', 'Reduce this circle to 50 saved places before enabling place alerts.');
    const places = {};
    for (const doc of legacy.docs) {
      if (!validId(doc.id)) continue;
      try {
        const fields = validatePlace(doc.data());
        places[doc.id] = { ...fields, geometry: hash(JSON.stringify([fields.latitude, fields.longitude, fields.radius])) };
      } catch (_) { /* Invalid legacy geometry cannot create a safety event. */ }
    }
    return { ref, places, missing: true };
  }
  async function mutate(request, operation) {
    const uid = authenticated(request), data = request.data || {}, circleId = data.circleId;
    if (!validId(circleId) || (data.placeId && !validId(data.placeId))) throw new HttpsError('invalid-argument', 'Select a saved place.');
    const ref = data.placeId ? db.doc(`places/${data.placeId}`) : db.collection('places').doc();
    const fields = operation === 'save' ? validatePlace(data.place) : null;
    if (operation === 'toggle' && (!validId(data.placeId) ||
      (data.notifyArrive !== undefined && typeof data.notifyArrive !== 'boolean') ||
      (data.notifyLeave !== undefined && typeof data.notifyLeave !== 'boolean') ||
      (data.notifyArrive === undefined && data.notifyLeave === undefined))) {
      throw new HttpsError('invalid-argument', 'Select an arrival or departure setting.');
    }
    return db.runTransaction(async (tx) => {
      const [profile, circle, existing, deletion, configuration] = await tx.getAll(
        db.doc(`users/${uid}`), db.doc(`circles/${circleId}`), ref, db.doc(`accountDeletions/${uid}`),
        db.doc(`circles/${circleId}/private/places`));
      const user = profile.data();
      if (!user || user.deletionRequested || deletion.exists || user.circleId !== circleId || user.role !== 'parent'
        || !circle.exists || !circle.data().memberIds?.includes(uid)) throw new HttpsError('permission-denied', 'Only a current parent can manage saved places.');
      if (existing.exists && existing.data().circleId !== circleId) throw new HttpsError('permission-denied', 'Place belongs to a different circle.');
      const config = await loadConfig(tx, circleId, configuration);
      const configured = { ...config.places };
      if (operation === 'toggle') {
        if (!existing.exists) throw new HttpsError('not-found', 'Place no longer exists.');
        tx.update(ref, { ...(data.notifyArrive !== undefined ? { notifyArrive: data.notifyArrive } : {}),
          ...(data.notifyLeave !== undefined ? { notifyLeave: data.notifyLeave } : {}), updatedAt: Timestamp.now() });
        if (configured[ref.id]) configured[ref.id] = { ...configured[ref.id],
          ...(data.notifyArrive !== undefined ? { notifyArrive: data.notifyArrive } : {}),
          ...(data.notifyLeave !== undefined ? { notifyLeave: data.notifyLeave } : {}) };
        tx.set(config.ref, { places: configured, updatedAt: Timestamp.now() });
        return { id: ref.id };
      }
      if (operation === 'delete') {
        if (!data.placeId) throw new HttpsError('invalid-argument', 'Select a saved place.');
        delete configured[ref.id];
        tx.set(config.ref, { places: configured, updatedAt: Timestamp.now() });
        tx.delete(ref); return { id: ref.id };
      }
      if (!existing.exists) {
        if (Object.keys(configured).length >= 50) throw new HttpsError('resource-exhausted', 'A circle can save up to 50 places.');
      }
      const old = existing.data();
      const geometry = hash(JSON.stringify([fields.latitude, fields.longitude, fields.radius]));
      configured[ref.id] = { ...fields, geometry };
      tx.set(config.ref, { places: configured, updatedAt: Timestamp.now() });
      tx.set(ref, { ...fields, id: ref.id, circleId, geometry,
        createdBy: old?.createdBy || uid, createdAt: old?.createdAt || Timestamp.now(), updatedAt: Timestamp.now() });
      return { id: ref.id };
    });
  }
  // Called inside the location transaction before any profile/history writes.
  async function recordTransitions(tx, uid, circleId, profile, point) {
    if (!point) return;
    const config = await loadConfig(tx, circleId);
    const places = Object.entries(config.places).map(([id, fields]) => ({ id, fields }));
    if (places.length === 0) {
      if (config.missing) tx.set(config.ref, { places: {}, updatedAt: Timestamp.now() });
      return;
    }
    const presenceRef = db.doc(`placePresence/${hash(`${uid}:${circleId}`)}`);
    const presence = await tx.get(presenceRef);
    const states = presence.data()?.states || {};
    const updated = {};
    for (let i = 0; i < places.length; i++) {
      const place = places[i], fields = place.fields, previous = states[place.id];
      if (typeof fields.name !== 'string' || !Number.isFinite(fields.latitude) || Math.abs(fields.latitude) > 90
        || !Number.isFinite(fields.longitude) || Math.abs(fields.longitude) > 180
        || !Number.isFinite(fields.radius) || fields.radius < 100 || fields.radius > 1000) continue;
      const metres = distance(point, fields);
      if (!Number.isFinite(metres) || !Number.isFinite(fields.radius)) continue;
      const geometry = fields.geometry || hash(JSON.stringify([fields.latitude, fields.longitude, fields.radius]));
      const baseline = !previous || previous.geometry !== geometry;
      let inside = baseline ? metres <= fields.radius : previous.inside;
      if (!baseline) {
        if (metres <= fields.radius - 25) inside = true;
        if (metres >= fields.radius + 25) inside = false;
      }
      const changed = !baseline && inside !== previous.inside;
      // Two observations separated by 30 seconds confirm a crossing.
      const candidateAt = changed && previous.candidate === inside ? previous.candidateAt : point.capturedAt;
      const confirmed = changed && point.capturedAt - candidateAt >= 30000;
      const timestamp = Timestamp.fromMillis(point.capturedAt);
      updated[place.id] = { geometry,
        inside: baseline || confirmed ? inside : previous.inside,
        candidate: changed ? inside : null, candidateAt: changed ? candidateAt : null,
        lastSeen: timestamp };
      if (confirmed && (inside ? fields.notifyArrive : fields.notifyLeave)) {
        tx.create(db.doc(`placeEvents/${hash(`${uid}:${circleId}:${place.id}:${point.id}`)}`), {
          circleId, memberId: uid, memberName: typeof profile.displayName === 'string' ? profile.displayName.slice(0, 80) : 'Family member',
          placeId: place.id, placeName: fields.name, type: inside ? 'arrive' : 'leave', timestamp, pushFanoutPending: true,
          expireAt: Timestamp.fromMillis(point.capturedAt + 30 * 86400000),
        });
      }
    }
    tx.set(presenceRef, { uid, circleId, states: updated,
      expireAt: Timestamp.fromMillis(point.capturedAt + 30 * 86400000) });
    if (config.missing) tx.set(config.ref, { places: config.places, updatedAt: Timestamp.now() });
  }
  return { save: (request) => mutate(request, 'save'), remove: (request) => mutate(request, 'delete'),
    toggle: (request) => mutate(request, 'toggle'), recordTransitions };
}
module.exports = { createPlaceHandlers, distance, validatePlace };
