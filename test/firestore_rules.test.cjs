const { before, after, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, collection, query, where, getDocs, Timestamp } = require('firebase/firestore');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-family-guard',
    firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 } });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [uid, circleId, role] of [['parentA', 'a', 'parent'], ['childA', 'a', 'child'], ['parentB', 'b', 'parent']]) {
      await setDoc(doc(db, 'users', uid), { uid, circleId, role, displayName: uid });
    }
    await setDoc(doc(db, 'circles/a'), { name: 'A', memberIds: ['parentA', 'childA'] });
    await setDoc(doc(db, 'circles/a/private/invites'), { parentInviteCode: 'secret' });
    await setDoc(doc(db, 'locationHistory/childA/points/p'), { latitude: 1, longitude: 2 });
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
  await assertSucceeds(updateDoc(doc(dbFor('childA'), 'sos_alerts/s'), { status: 'resolved', resolvedBy: 'childA', durationSeconds: 1, resolvedAt: 'now' }));
});
test('history requires timestamp TTL and valid coordinates', async () => {
  const point = { latitude: 1, longitude: 2, timestamp: Timestamp.now(), expireAt: Timestamp.now() };
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
