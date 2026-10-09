const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const req = createRequire(resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = req('firebase-admin/app');
const { getFirestore } = req('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-family-guard' }, 'places-integration');
const db = getFirestore(app);
const places = require('../functions/features/places').createPlaceHandlers(db);
const locations = require('../functions/features/locations').createLocationHandlers(db);
after(() => deleteApp(app));
const request = (uid, data) => ({ auth: { uid }, data: { expectedUid: uid, ...data } });
const place = { name: 'Home', address: '', category: 'home', latitude: 0, longitude: 0,
  radius: 100, colorValue: 0xff00ff00, notifyArrive: true, notifyLeave: true };
async function setup(id) {
  await db.doc(`users/${id}-parent`).set({ role: 'parent', circleId: id });
  await db.doc(`users/${id}-child`).set({ role: 'child', circleId: id, displayName: 'Child' });
  await db.doc(`circles/${id}`).set({ memberIds: [`${id}-parent`, `${id}-child`] });
  return (await places.save(request(`${id}-parent`, { circleId: id, place }))).id;
}
function upload(id, key, age, latitude) {
  return locations.ingest(request(`${id}-child`, { circleId: id, fixes: [{
    id: key.repeat(64), capturedAt: Date.now() - age, latitude, longitude: 0,
    speedMph: 0, movementActivity: 'stationary', batteryLevel: 80, isCharging: false,
  }] }));
}
test('current parents own validated place management', async () => {
  const id = 'place-authority', placeId = await setup(id);
  await assert.rejects(places.save(request(`${id}-child`, { circleId: id, place })), { code: 'permission-denied' });
  await assert.rejects(places.save(request(`${id}-parent`, { circleId: id, place: { ...place, radius: 99 } })), { code: 'invalid-argument' });
  await setup('place-other');
  await assert.rejects(places.remove(request('place-other-parent', { circleId: 'place-other', placeId })), { code: 'permission-denied' });
  await places.remove(request(`${id}-parent`, { circleId: id, placeId }));
  assert.equal((await db.doc(`places/${placeId}`).get()).exists, false);
});
test('simultaneous additions cannot exceed the 50-place circle cap', async () => {
  const id = 'place-cap'; await setup(id);
  const batch = db.batch();
  for (let i = 0; i < 48; i++) batch.set(db.doc(`places/cap-${i}`), { ...place, circleId: id });
  await batch.commit();
  const current = await db.collection('places').where('circleId', '==', id).get();
  await db.doc(`circles/${id}/private/places`).set({ places: Object.fromEntries(current.docs.map((doc) => [doc.id, { ...place }])) });
  const results = await Promise.allSettled([places.save(request(`${id}-parent`, { circleId: id, place })), places.save(request(`${id}-parent`, { circleId: id, place }))]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.find((result) => result.status === 'rejected').reason.code, 'resource-exhausted');
});
test('baseline and boundary jitter stay quiet; confirmed crossings create events', async () => {
  const id = 'place-crossing'; await setup(id);
  await upload(id, '1', 110000, 0.01);
  await upload(id, '2', 90000, 0.00088); // Within boundary uncertainty band.
  assert.equal((await db.collection('placeEvents').where('circleId', '==', id).get()).size, 0);
  await upload(id, '3', 80000, 0);
  await upload(id, '4', 40000, 0);
  await upload(id, '5', 35000, 0.01);
  await upload(id, '6', 1000, 0.01);
  const events = (await db.collection('placeEvents').where('circleId', '==', id).get()).docs.map((doc) => doc.data());
  assert.deepEqual(events.map((event) => event.type).sort(), ['arrive', 'leave']);
  assert.equal(events.every((event) => event.memberId === `${id}-child`), true);
});
test('simultaneous notification toggles preserve independent fields', async () => {
  const id = 'place-toggle', placeId = await setup(id);
  await Promise.all([
    places.toggle(request(`${id}-parent`, { circleId: id, placeId, notifyArrive: false })),
    places.toggle(request(`${id}-parent`, { circleId: id, placeId, notifyLeave: false })),
  ]);
  const saved = (await db.doc(`places/${placeId}`).get()).data();
  assert.equal(saved.notifyArrive, false); assert.equal(saved.notifyLeave, false);
  assert.equal(saved.name, 'Home');
});
test('disabled notifications update presence without producing an event', async () => {
  const id = 'place-muted', placeId = await setup(id);
  await places.save(request(`${id}-parent`, { circleId: id, placeId, place: { ...place, notifyArrive: false } }));
  await upload(id, '7', 100000, 0.01); await upload(id, '8', 60000, 0); await upload(id, '9', 1000, 0);
  assert.equal((await db.collection('placeEvents').where('circleId', '==', id).get()).size, 0);
  const presence = (await db.collection('placePresence').where('uid', '==', `${id}-child`).get()).docs[0].data();
  assert.equal(Object.values(presence.states)[0].inside, true);
});
test('place geometry changes reset the baseline instead of inventing a crossing', async () => {
  const id = 'place-geometry', placeId = await setup(id);
  await upload(id, 'a', 100000, 0);
  await places.save(request(`${id}-parent`, { circleId: id, placeId, place: { ...place, latitude: 1 } }));
  await upload(id, 'b', 1000, 0);
  assert.equal((await db.collection('placeEvents').where('circleId', '==', id).get()).size, 0);
});
