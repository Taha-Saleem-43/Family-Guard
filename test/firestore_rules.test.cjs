const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, collection, query, where, getDocs, Timestamp, orderBy, documentId, startAfter, limit } = require('firebase/firestore');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-family-guard',
    firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 } });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [uid, circleId, role] of [['parentA', 'a', 'parent'], ['childA', 'a', 'child'], ['siblingA', 'a', 'child'], ['parentB', 'b', 'parent']]) {
      await setDoc(doc(db, 'users', uid), { uid, circleId, role, displayName: uid });
    }
    await setDoc(doc(db, 'circles/a'), { name: 'A', memberIds: ['parentA', 'childA'] });
    await setDoc(doc(db, 'circles/a/private/invites'), { parentInviteCode: 'secret' });
    await setDoc(doc(db, 'locationHistory/childA/points/p'), { latitude: 1, longitude: 2, circleId: 'a' });
    await setDoc(doc(db, 'sos_alerts/s'), { circleId: 'a', senderId: 'childA', status: 'active' });
  });
});
after(async () => { if (env) await env.cleanup(); });
const dbFor = (uid) => env.authenticatedContext(uid).firestore();
test('anonymous and other circles cannot read location-bearing profiles', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/childA')));
  await assertFails(getDoc(doc(dbFor('parentB'), 'users/childA')));
  await assertSucceeds(getDoc(doc(dbFor('parentA'), 'users/childA')));
});
test('roster queries must constrain circle membership', async () => {
  await assertSucceeds(getDocs(query(collection(dbFor('parentA'), 'users'), where('circleId', '==', 'a'))));
  await assertFails(getDocs(collection(dbFor('parentA'), 'users')));
});
test('clients cannot promote themselves or forge membership', async () => {
  await assertFails(updateDoc(doc(dbFor('childA'), 'users/childA'), { role: 'parent' }));
  await assertFails(updateDoc(doc(dbFor('parentB'), 'users/parentB'), { circleId: 'a' }));
  await assertFails(updateDoc(doc(dbFor('childA'), 'circles/a'), { memberIds: ['childA'] }));
});
test('profiles cannot be created with privileged membership', async () => {
  const profile = { uid: 'new', email: 'new@example.com', displayName: 'New', role: 'child', circleId: null, createdAt: 'today' };
  await assertFails(setDoc(doc(dbFor('new'), 'users/new'), { ...profile, role: 'parent', circleId: 'a' }));
  await assertSucceeds(setDoc(doc(dbFor('new'), 'users/new'), profile));
});
test('history access is limited to owner or parent in same circle', async () => {
  await assertSucceeds(getDoc(doc(dbFor('parentA'), 'locationHistory/childA/points/p')));
  await assertFails(getDoc(doc(dbFor('parentB'), 'locationHistory/childA/points/p')));
});
test('invite secrets are parent-only and backend-owned', async () => {
  await assertSucceeds(getDoc(doc(dbFor('parentA'), 'circles/a/private/invites')));
  await assertFails(getDoc(doc(dbFor('childA'), 'circles/a/private/invites')));
  await assertFails(setDoc(doc(dbFor('parentA'), 'circleInvites/forged'), { circleId: 'a' }));
});
test('SOS cannot be spoofed or resolved by another member', async () => {
  await assertFails(setDoc(doc(dbFor('parentB'), 'sos_alerts/fake'), { circleId: 'a', senderId: 'childA', status: 'active' }));
  await assertFails(updateDoc(doc(dbFor('parentA'), 'sos_alerts/s'), { status: 'resolved', resolvedBy: 'parentA' }));
  await assertFails(updateDoc(doc(dbFor('childA'), 'sos_alerts/s'), { status: 'resolved', resolvedBy: 'childA', durationSeconds: 1, resolvedAt: 'now' }));
  await assertFails(setDoc(doc(dbFor('childA'), 'sos_alerts/own'), { circleId: 'a', senderId: 'childA', status: 'active' }));
  await assertFails(updateDoc(doc(dbFor('childA'), 'users/childA'), { isSosActive: false, activeSosId: null }));
});
test('history requires timestamp TTL and valid coordinates', async () => {
  const point = { circleId: 'a', latitude: 1, longitude: 2, timestamp: Timestamp.now(), expireAt: Timestamp.now() };
  await assertSucceeds(setDoc(doc(dbFor('childA'), 'locationHistory/childA/points/valid'), point));
  await assertFails(setDoc(doc(dbFor('childA'), 'locationHistory/childA/points/invalid'), { ...point, latitude: 91 }));
  await assertFails(setDoc(doc(dbFor('childA'), 'locationHistory/childA/points/string'), { ...point, expireAt: 'tomorrow' }));
});
test('place management belongs to parents in the circle', async () => {
  const place = { circleId: 'a', createdBy: 'parentA', latitude: 1, longitude: 2, radius: 200 };
  await assertSucceeds(setDoc(doc(dbFor('parentA'), 'places/home'), place));
  await assertFails(setDoc(doc(dbFor('childA'), 'places/school'), { ...place, createdBy: 'childA' }));
  await assertFails(setDoc(doc(dbFor('parentB'), 'places/foreign'), { ...place, createdBy: 'parentB' }));
});

test('children can read themselves but cannot query other location profiles', async () => {
  await assertSucceeds(getDoc(doc(dbFor('childA'), 'users/childA')));
  await assertFails(getDoc(doc(dbFor('childA'), 'users/parentA')));
  await assertFails(getDoc(doc(dbFor('childA'), 'users/siblingA')));
  await assertFails(getDocs(query(collection(dbFor('childA'), 'users'), where('circleId', '==', 'a'))));
});

test('profile updates reject malformed display and tracking fields', async () => {
  const profile = doc(dbFor('childA'), 'users/childA');
  for (const fields of [
    { displayName: 42 }, { displayName: '' }, { displayName: 'x'.repeat(81) },
    { batteryLevel: -2 }, { batteryLevel: 101 }, { batteryLevel: 50.5 },
    { isCharging: 'yes' }, { speedMph: -1 }, { speedMph: 'fast' },
    { movementActivity: 'flying' }, { lastSeen: 123 },
  ]) await assertFails(updateDoc(profile, fields));
  await assertSucceeds(updateDoc(profile, { displayName: 'Child', batteryLevel: 80,
    isCharging: false, speedMph: 0, movementActivity: 'stationary', lastSeen: new Date().toISOString() }));
  await assertSucceeds(updateDoc(profile, { latitude: 1, longitude: 2 }));
  // Native battery APIs use -1 when the reading is unavailable. Do not reject the location batch.
  await assertSucceeds(updateDoc(profile, { batteryLevel: -1, latitude: 2, longitude: 3 }));
});

test('parents cannot read a member history recorded in another circle or without provenance', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    for (const [id, data] of [['previous', {circleId: 'former'}], ['legacy', {}]]) {
      await setDoc(doc(context.firestore(), `locationHistory/childA/points/${id}`), {
        latitude: 1, longitude: 2, timestamp: Timestamp.now(), ...data,
      });
    }
  });
  for (const id of ['previous', 'legacy']) {
    await assertFails(getDoc(doc(dbFor('parentA'), `locationHistory/childA/points/${id}`)));
    await assertSucceeds(getDoc(doc(dbFor('childA'), `locationHistory/childA/points/${id}`)));
  }
  await assertSucceeds(getDocs(query(collection(dbFor('parentA'), 'locationHistory/childA/points'), where('circleId', '==', 'a'))));
  await assertFails(getDocs(collection(dbFor('parentA'), 'locationHistory/childA/points')));
  const point = {circleId: 'former', latitude: 1, longitude: 2, timestamp: Timestamp.now(), expireAt: Timestamp.now()};
  await assertFails(setDoc(doc(dbFor('childA'), 'locationHistory/childA/points/forged-circle'), point));
});

test('parent history cursors preserve every point when timestamps are identical', async () => {
  const timestamp = Timestamp.fromDate(new Date('2026-10-09T00:00:00Z'));
  await env.withSecurityRulesDisabled(async (context) => {
    for (const id of ['a', 'b', 'c']) await setDoc(doc(context.firestore(), `locationHistory/siblingA/points/${id}`), {
      circleId: 'a', latitude: 1, longitude: 2, timestamp,
    });
  });
  const base = query(collection(dbFor('parentA'), 'locationHistory/siblingA/points'),
    where('circleId', '==', 'a'), where('timestamp', '>=', timestamp), where('timestamp', '<=', timestamp),
    orderBy('timestamp', 'desc'), orderBy(documentId(), 'desc'));
  const first = await assertSucceeds(getDocs(query(base, limit(2))));
  assert.deepEqual(first.docs.map((point) => point.id), ['c', 'b']);
  const second = await assertSucceeds(getDocs(query(base, startAfter(timestamp, 'b'), limit(2))));
  assert.deepEqual(second.docs.map((point) => point.id), ['a']);
});
