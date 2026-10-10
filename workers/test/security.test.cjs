const { test } = require("node:test");
const assert = require("node:assert/strict");
const { generateKeyPairSync, createSign } = require("node:crypto");
const { verifyJwt, GoogleClient } = require("../src/google.cjs");
const {
  encode,
  decode,
  write,
  Firestore,
  Timestamp,
  FieldValue,
} = require("../src/firestore.cjs");
const { privateKey, publicKey } = generateKeyPairSync("rsa", {
  modulusLength: 2048,
});
const jwk = {
  ...publicKey.export({ format: "jwk" }),
  kid: "test-key",
  alg: "RS256",
  use: "sig",
};
const now = Math.floor(Date.now() / 1000);
const valid = {
  aud: "project",
  iss: "issuer",
  sub: "user",
  iat: now,
  exp: now + 3600,
};
const b64 = (v) => Buffer.from(JSON.stringify(v)).toString("base64url");
function signed(claims = valid, header = { alg: "RS256", kid: "test-key" }) {
  const data = b64(header) + "." + b64(claims);
  return (
    data +
    "." +
    createSign("RSA-SHA256").update(data).sign(privateKey).toString("base64url")
  );
}
const fetchKeys = async () => new Response(JSON.stringify({ keys: [jwk] }));
const claimsValid = (c) =>
  c.aud === "project" && c.iss === "issuer" && c.sub === "user";

test("FCM SDK configuration is translated to the REST enum and duration format", async () => {
  const client = new GoogleClient({ FIREBASE_PROJECT_ID: "demo" });
  client.request = async (url, body) => {
    assert.match(url, /\/messages:send$/);
    assert.deepEqual(body.message.android, {
      priority: "HIGH",
      ttl: "300s",
      notification: { channelId: "family_guard_sos", visibility: "PRIVATE" },
    });
    return { name: "sent" };
  };
  assert.equal(
    await client.send({
      token: "fake",
      android: {
        priority: "high",
        ttl: 300000,
        notification: { channelId: "family_guard_sos", visibility: "private" },
      },
    }),
    "sent",
  );
});
test("JWT signature, issuer and audience are required", async () => {
  assert.equal(
    (await verifyJwt(signed(), "https://keys.test/one", claimsValid, fetchKeys))
      .sub,
    "user",
  );
  for (const claims of [
    { ...valid, aud: "other" },
    { ...valid, iss: "other" },
    { ...valid, exp: now - 1 },
    { ...valid, iat: now + 100 },
    { ...valid, nbf: now + 100 },
  ])
    await assert.rejects(
      verifyJwt(
        signed(claims),
        "https://keys.test/one",
        claimsValid,
        fetchKeys,
      ),
      { code: "unauthenticated" },
    );
  await assert.rejects(
    verifyJwt(
      signed(valid, { alg: "none", kid: "test-key" }),
      "https://keys.test/one",
      claimsValid,
      fetchKeys,
    ),
    { code: "unauthenticated" },
  );
  const bad = signed().split(".");
  bad[1] = b64({ ...valid, admin: true });
  await assert.rejects(
    verifyJwt(bad.join("."), "https://keys.test/one", claimsValid, fetchKeys),
    { code: "unauthenticated" },
  );
});
test("malformed and missing tokens are rejected before fetching keys", async () => {
  for (const token of [null, "x", "a.b.c", "x".repeat(17000)])
    await assert.rejects(
      verifyJwt(
        token,
        "https://keys.test/bad",
        () => true,
        () => assert.fail("Unexpected network call"),
      ),
      { code: "unauthenticated" },
    );
});
test("key endpoint failures do not accept unverified identities", async () => {
  await assert.rejects(
    verifyJwt(
      signed(),
      "https://keys.test/unavailable",
      claimsValid,
      async () => new Response("{}", { status: 503 }),
    ),
    { code: "unavailable" },
  );
});
test("server credentials are bound to the configured project", async () => {
  const client = new GoogleClient(
    {
      FIREBASE_PROJECT_ID: "target",
      GOOGLE_SERVICE_ACCOUNT: JSON.stringify({
        project_id: "other",
        client_email: "fake",
        private_key: "fake",
      }),
    },
    () => assert.fail("Unexpected network"),
  );
  await assert.rejects(client.token(), { code: "failed-precondition" });
});
test("Firestore timestamps and nested fields retain types", () => {
  const data = {
    timestamp: Timestamp.fromMillis(1720000000000),
    array: [null, 3, true, "x"],
    map: { "a.b": 12.5 },
  };
  const value = decode(encode(data));
  assert.equal(value.timestamp.toMillis(), data.timestamp.toMillis());
  assert.deepEqual(value.array, data.array);
  assert.deepEqual(value.map, data.map);
});
test("update deletion, transforms and creation preconditions are preserved", () => {
  const ref = { name: "projects/demo/databases/(default)/documents/users/a" };
  const result = write(
    ref,
    {
      private: FieldValue.delete(),
      count: FieldValue.increment(1),
      members: FieldValue.arrayUnion("a"),
      name: "Safe",
    },
    "update",
  );
  assert.deepEqual(result.currentDocument, { exists: true });
  assert.equal(result.update.fields.private, undefined);
  assert.deepEqual(result.updateMask.fieldPaths, ["`private`", "`name`"]);
  assert.deepEqual(result.updateTransforms, [
    { fieldPath: "`count`", increment: { integerValue: "1" } },
    {
      fieldPath: "`members`",
      appendMissingElements: { values: [{ stringValue: "a" }] },
    },
  ]);
  assert.equal(
    write(ref, { name: "new" }, "create").currentDocument.exists,
    false,
  );
});
test("transaction aborts rerun the complete callback and roll back", async () => {
  let callbacks = 0,
    commits = 0,
    rollbacks = 0;
  const db = new Firestore("demo", async (path) => {
    if (path.endsWith(":beginTransaction")) return { transaction: "lease" };
    if (path.endsWith(":rollback")) {
      rollbacks++;
      return {};
    }
    if (path.endsWith(":commit")) {
      if (commits++ === 0)
        throw Object.assign(new Error("conflict"), { code: "aborted" });
      return {};
    }
    throw new Error("Unexpected request");
  });
  const value = await db.runTransaction((tx) => {
    callbacks++;
    tx.create(db.doc("users/a"), { ok: true });
    return "result";
  });
  assert.equal(value, "result");
  assert.equal(callbacks, 2);
  assert.equal(rollbacks, 1);
});
test("nonretryable transaction failures do not repeat side effects", async () => {
  let callbacks = 0;
  const db = new Firestore("demo", async (path) =>
    path.endsWith(":beginTransaction") ? { transaction: "lease" } : {},
  );
  await assert.rejects(
    db.runTransaction(() => {
      callbacks++;
      throw Object.assign(new Error("denied"), { code: "permission-denied" });
    }),
    { code: "permission-denied" },
  );
  assert.equal(callbacks, 1);
});
