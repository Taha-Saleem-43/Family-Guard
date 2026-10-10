const { test } = require("node:test");
const assert = require("node:assert/strict");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  createAccountDeletionHandlers,
} = require("../../functions/features/accounts");
const db = getFirestore();

test("independent REST clients converge under repeated simultaneous uploads", async () => {
  const { Firestore } = require("../src/firestore.cjs");
  const {
    createLocationHandlers,
  } = require("../../functions/features/locations");
  const { createHash } = require("node:crypto");
  const clients = [0, 1].map(
    () =>
      createLocationHandlers(new Firestore("demo-family-guard", db.request))
        .ingest,
  );
  for (let round = 0; round < 6; round++) {
    const uid = `contention-${round}`;
    await db.doc(`users/${uid}`).set({ role: "child", circleId: uid });
    await db.doc(`circles/${uid}`).set({ memberIds: [uid] });
    const now = Date.now();
    await Promise.all(
      clients.map((ingest, index) =>
        ingest({
          auth: {
            uid,
            token: { auth_time: Math.floor((now - 120000) / 1000) },
          },
          data: {
            expectedUid: uid,
            circleId: uid,
            sharingStartedAt: now - 60000,
            fixes: [
              {
                id: createHash("sha256")
                  .update(`${round}:${index}`)
                  .digest("hex"),
                capturedAt: now - (index ? 1000 : 10000),
                latitude: index ? 20 : 10,
                longitude: 2,
                speedMph: 0,
                movementActivity: "stationary",
                batteryLevel: -1,
                isCharging: false,
              },
            ],
          },
        }),
      ),
    );
    assert.equal((await db.doc(`users/${uid}`).get()).data().latitude, 20);
    assert.equal(
      (await db.collection(`locationHistory/${uid}/points`).get()).size,
      2,
    );
  }
});

test("collection-group retention selects expired history across accounts", async () => {
  const expired = db.doc("locationHistory/retention-a/points/expired");
  const fresh = db.doc("locationHistory/retention-b/points/fresh");
  await expired.set({ expireAt: Timestamp.fromMillis(Date.now() - 1000) });
  await fresh.set({ expireAt: Timestamp.fromMillis(Date.now() + 60000) });
  const result = await db
    .collectionGroup("points")
    .where("expireAt", "<=", Timestamp.now())
    .limit(25)
    .get();
  assert.deepEqual(
    result.docs.map((doc) => doc.ref.path),
    [expired.path],
  );
  const batch = db.batch();
  for (const doc of result.docs) batch.delete(doc.ref);
  await batch.commit();
  assert.equal((await fresh.get()).exists, true);
});
test("bounded account cleanup resumes until private data and identity are removed", async () => {
  const uid = "bounded-deletion";
  await db.doc(`users/${uid}`).set({ circleId: uid, role: "parent" });
  await db.doc(`circles/${uid}`).set({ memberIds: [uid], createdBy: uid });
  await db.doc(`circles/${uid}/private/invites`).set({ secret: "private" });
  await db.doc(`locationHistory/${uid}/points/one`).set({ latitude: 1 });
  let removed = 0;
  const handlers = createAccountDeletionHandlers(
    db,
    {
      updateUser: async () => {},
      deleteUser: async () => {
        removed++;
      },
    },
    { stepsPerRun: 4, pagesPerRun: 1 },
  );
  await handlers.request({
    auth: { uid, token: { auth_time: Math.floor(Date.now() / 1000) } },
    data: { expectedUid: uid },
  });
  await handlers.process(uid);
  assert.equal(
    (await db.doc(`accountDeletions/${uid}`).get()).data().status,
    "pending",
  );
  assert.equal(removed, 0);
  for (let attempt = 0; attempt < 12; attempt++) await handlers.process(uid);
  assert.equal(
    (await db.doc(`accountDeletions/${uid}`).get()).data().status,
    "complete",
  );
  for (const path of [
    `users/${uid}`,
    `circles/${uid}/private/invites`,
    `locationHistory/${uid}/points/one`,
  ])
    assert.equal((await db.doc(path).get()).exists, false);
  assert.equal(removed, 1);
});
