// Exercise the actual Workers runtime with fake keys and fake Google responses.
// No Firebase credentials, production accounts or external requests are used.
const { Miniflare, convertV4MiniflareOptions } = require("miniflare");
const assert = require("node:assert/strict");
const { resolve } = require("node:path");
const { generateKeyPairSync, createSign, createHmac } = require("node:crypto");
const { privateKey, publicKey } = generateKeyPairSync("rsa", {
  modulusLength: 2048,
});
const jwk = { ...publicKey.export({ format: "jwk" }), kid: "runtime-key" };
const env = {
  FIREBASE_PROJECT_ID: "familyguard-v2-app",
  FIREBASE_PROJECT_NUMBER: "160141197240",
  FIREBASE_APP_IDS: "runtime-app",
};
env.GOOGLE_SERVICE_ACCOUNT = JSON.stringify({
  project_id: env.FIREBASE_PROJECT_ID,
  client_email: "test@example.invalid",
  private_key: privateKey.export({ format: "pem", type: "pkcs8" }),
});
const now = Math.floor(Date.now() / 1000);
function signed(claims) {
  const b64 = (v) => Buffer.from(JSON.stringify(v)).toString("base64url");
  const data =
    b64({ alg: "RS256", kid: jwk.kid }) +
    "." +
    b64({ iat: now, exp: now + 3600, ...claims });
  return (
    data +
    "." +
    createSign("RSA-SHA256").update(data).sign(privateKey).toString("base64url")
  );
}
const auth = signed({
  aud: env.FIREBASE_PROJECT_ID,
  iss: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
  sub: "runtime-user",
  auth_time: now,
});
const app = signed({
  aud: [`projects/${env.FIREBASE_PROJECT_NUMBER}`],
  iss: `https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`,
  sub: "runtime-app",
});
let commits = 0;
const testBundle = resolve(__dirname, "../../build/workers/index.js");
const mf = new Miniflare(
  convertV4MiniflareOptions({
    workers: [
      {
        name: "runtime-test",
        modules: true,
        modulesRoot: resolve(__dirname, "../.."),
        scriptPath: testBundle,
        compatibilityDate: "2026-10-10",
        compatibilityFlags: ["nodejs_compat", "global_fetch_strictly_public"],
        bindings: env,
        outboundService: async (request) => {
          const url = new URL(request.url);
          let data;
          if (
            url.pathname.endsWith("/jwks") ||
            url.pathname.includes("/jwk/securetoken@")
          )
            data = { keys: [jwk] };
          else if (url.hostname === "oauth2.googleapis.com")
            data = { access_token: "test-only-token", expires_in: 3600 };
          else if (url.hostname === "firestore.googleapis.com") {
            const input = await request.json();
            if (url.pathname.endsWith(":beginTransaction"))
              data = { transaction: "test-transaction" };
            else if (url.pathname.endsWith(":batchGet"))
              data = input.documents.map((name) =>
                name.endsWith("/users/runtime-user")
                  ? {
                      found: {
                        name,
                        fields: { role: { stringValue: "child" } },
                      },
                    }
                  : { missing: name },
              );
            else if (url.pathname.endsWith(":commit")) {
              commits++;
              assert.ok(input.writes.length === 0 || input.writes.length >= 4);
              data = {};
            } else throw new Error("Unexpected Firestore operation");
          } else
            throw new Error("External network request blocked in runtime test");
          return new Response(JSON.stringify(data), {
            headers: { "Content-Type": "application/json" },
          });
        },
      },
    ],
  }),
);
(async () => {
  try {
    const health = await mf.dispatchFetch("https://worker.test/health");
    assert.equal(health.status, 200);
    const response = await mf.dispatchFetch(
      "https://worker.test/createCircle",
      {
        method: "POST",
        headers: {
          Authorization: "Bearer " + auth,
          "X-Firebase-AppCheck": app,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          data: { expectedUid: "runtime-user", circleName: "Runtime family" },
        }),
      },
    );
    const payload = await response.json();
    assert.equal(response.status, 200, JSON.stringify(payload));
    assert.equal(payload.result.name, "Runtime family");
    assert.equal(commits, 1);
    for (const name of [
      "enqueueSosPush",
      "enqueuePlacePush",
      "deliverSosPush",
      "deliverPlacePush",
      "processAccountDeletion",
    ]) {
      const path = `/_jobs/${name}/missing-job`,
        time = String(Date.now());
      const signature = createHmac("sha256", env.GOOGLE_SERVICE_ACCOUNT)
        .update(time + "\n" + path)
        .digest("hex");
      const result = await mf.dispatchFetch("https://worker.test" + path, {
        method: "POST",
        headers: { "X-Job-Time": time, "X-Job-Signature": signature },
      });
      assert.equal(
        result.status,
        200,
        `${name} failed: ${await result.text()}`,
      );
    }
    console.log(
      "Workers runtime: JWT verification, OAuth signing, transactional circle creation and callable response passed.",
    );
  } finally {
    await mf.dispose();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
