const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { generateKeyPairSync, createSign, createHmac } = require("node:crypto");
const { validJob } = require("../src/jobs.cjs");
const { privateKey, publicKey } = generateKeyPairSync("rsa", {
  modulusLength: 2048,
});
const jwk = { ...publicKey.export({ format: "jwk" }), kid: "http-test-key" };
const env = {
  FIREBASE_PROJECT_ID: "familyguard-v2-app",
  FIREBASE_PROJECT_NUMBER: "160141197240",
  FIREBASE_APP_IDS: "test-app",
  GOOGLE_SERVICE_ACCOUNT: "test-only-secret",
};
const now = Math.floor(Date.now() / 1000);
const auth = {
  aud: env.FIREBASE_PROJECT_ID,
  iss: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
  sub: "test-user",
  auth_time: now,
  iat: now,
  exp: now + 3600,
};
const app = {
  aud: [`projects/${env.FIREBASE_PROJECT_NUMBER}`],
  iss: `https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`,
  sub: "test-app",
  iat: now,
  exp: now + 3600,
};
function token(claims) {
  const b64 = (v) => Buffer.from(JSON.stringify(v)).toString("base64url");
  const data = b64({ alg: "RS256", kid: jwk.kid }) + "." + b64(claims);
  return (
    data +
    "." +
    createSign("RSA-SHA256").update(data).sign(privateKey).toString("base64url")
  );
}
const oldFetch = global.fetch;
let worker;
before(async () => {
  global.fetch = async (url) => {
    assert.match(String(url), /\/jwk\/securetoken@|\/v1\/jwks$/);
    return new Response(JSON.stringify({ keys: [jwk] }));
  };
  const source = readFileSync(
    resolve(__dirname, "../../build/workers/index.js"),
    "utf8",
  );
  worker = (
    await import(
      "data:text/javascript;base64," + Buffer.from(source).toString("base64")
    )
  ).default;
});
after(() => (global.fetch = oldFetch));
function call(
  path,
  data,
  { id = auth, attestation = app, method = "POST" } = {},
) {
  const headers = { "Content-Type": "application/json" };
  if (id) headers.Authorization = "Bearer " + token(id);
  if (attestation) headers["X-Firebase-AppCheck"] = token(attestation);
  return worker.fetch(
    new Request("https://worker.test" + path, {
      method,
      headers,
      ...(method === "POST"
        ? { body: typeof data === "string" ? data : JSON.stringify(data) }
        : {}),
    }),
    env,
    { waitUntil: () => assert.fail("Unexpected background job") },
  );
}
test("only named public operations are callable", async () => {
  for (const path of [
    "/missing",
    "/retryAccountDeletions",
    "/deliverSosPush",
    "/toString",
  ])
    assert.equal((await call(path, { data: {} })).status, 404);
  assert.equal(
    (await call("/createCircle", null, { method: "GET" })).status,
    404,
  );
});
test("both a project identity and a trusted app are required", async () => {
  for (const options of [
    { id: null },
    { attestation: null },
    { id: { ...auth, aud: "foreign-project" } },
    { attestation: { ...app, sub: "foreign-app" } },
  ]) {
    const response = await call("/createCircle", { data: {} }, options);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.status, "UNAUTHENTICATED");
  }
});
test("malformed envelopes and oversized bodies are rejected", async () => {
  for (const data of [
    "{",
    {},
    [],
    { data: null },
    { data: [] },
    { data: {}, unexpected: true },
  ])
    assert.equal((await call("/createCircle", data)).status, 400);
  assert.equal((await call("/createCircle", "x".repeat(65537))).status, 429);
});
test("business validation retains Firebase callable error semantics", async () => {
  const wrongUser = await call("/createCircle", {
    data: { expectedUid: "another-user", circleName: "Family" },
  });
  assert.equal(wrongUser.status, 400);
  assert.equal((await wrongUser.json()).error.status, "FAILED_PRECONDITION");
  const emptyName = await call("/createCircle", {
    data: { expectedUid: "test-user", circleName: "" },
  });
  assert.equal(emptyName.status, 400);
  assert.equal((await emptyName.json()).error.status, "INVALID_ARGUMENT");
});
test("internal jobs cannot be invoked by public Firebase tokens", async () => {
  assert.equal(
    (await call("/_jobs/processAccountDeletion/test-user", { data: {} }))
      .status,
    401,
  );
  const path = "/_jobs/deliverSosPush/job-id",
    time = String(Date.now());
  const signature = createHmac("sha256", env.GOOGLE_SERVICE_ACCOUNT)
    .update(time + "\n" + path)
    .digest("hex");
  const request = (url, t = time, s = signature) =>
    new Request("https://worker.test" + url, {
      method: "POST",
      headers: { "X-Job-Time": t, "X-Job-Signature": s },
    });
  assert.deepEqual(validJob(request(path), env), {
    name: "deliverSosPush",
    id: "job-id",
  });
  assert.equal(
    validJob(request("/_jobs/processAccountDeletion/job-id"), env),
    null,
  );
  assert.equal(validJob(request(path, String(Date.now() - 61000)), env), null);
  assert.equal(validJob(request(path, time, "0".repeat(64)), env), null);
});
test("health reports missing configuration without disclosing credentials", async () => {
  const request = new Request("https://worker.test/health");
  const response = await worker.fetch(request, {}, {});
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { status: "configuration-required" });
});
