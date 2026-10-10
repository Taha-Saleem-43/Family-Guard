import backend from "../../functions/index.js";
import state from "./state.cjs";
import google from "./google.cjs";
import firestore from "./firestore.cjs";
import jobs from "./jobs.cjs";
import accountsModule from "../../functions/features/accounts.js";

const { scope, db } = state;
const { GoogleClient, ApiError, verifyRequest } = google;
const accountJobs = accountsModule.createAccountDeletionHandlers(
  db,
  {
    updateUser: (...args) => scope.getStore().client.updateUser(...args),
    deleteUser: (...args) => scope.getStore().client.deleteUser(...args),
  },
  { stepsPerRun: 4, pagesPerRun: 1 },
);
const statusCodes = {
  "invalid-argument": 400,
  unauthenticated: 401,
  "permission-denied": 403,
  "not-found": 404,
  "already-exists": 409,
  aborted: 409,
  "failed-precondition": 400,
  "resource-exhausted": 429,
  unavailable: 503,
};
const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "Authorization,Content-Type,X-Firebase-AppCheck",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};
const response = (value, status = 200) =>
  new Response(JSON.stringify(value), { status, headers });
function configured(env) {
  return (
    env.FIREBASE_PROJECT_ID === "familyguard-v2-app" &&
    env.FIREBASE_PROJECT_NUMBER === "160141197240" &&
    env.GOOGLE_SERVICE_ACCOUNT
  );
}
function scoped(env, operation) {
  if (!configured(env)) throw new ApiError("failed-precondition");
  const client = new GoogleClient(env);
  return scope.run({ client, env, created: [] }, operation);
}
async function body(request) {
  const reader = request.body?.getReader();
  if (!reader) throw new ApiError("invalid-argument");
  let length = 0;
  const chunks = [];
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    length += value.length;
    if (length > 65536) {
      await reader.cancel();
      throw new ApiError("resource-exhausted");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  let value;
  try {
    value = JSON.parse(new TextDecoder().decode(bytes));
  } catch (_) {
    throw new ApiError("invalid-argument");
  }
  if (
    !value ||
    Array.isArray(value) ||
    typeof value.data !== "object" ||
    value.data === null ||
    Array.isArray(value.data) ||
    Object.keys(value).some((k) => k !== "data")
  )
    throw new ApiError("invalid-argument");
  return value.data;
}
async function createdEvents() {
  const current = scope.getStore();
  let handled = 0;
  while (current.created.length && handled++ < 30) {
    const path = current.created.shift();
    for (const [name, handler] of Object.entries(backend)) {
      if (handler.kind !== "document") continue;
      const pattern = handler.options.document.split("/"),
        actual = path.split("/");
      if (pattern.length !== actual.length) continue;
      const params = {};
      let matches = true;
      for (let i = 0; i < pattern.length; i++) {
        if (pattern[i].startsWith("{"))
          params[pattern[i].slice(1, -1)] = actual[i];
        else if (pattern[i] !== actual[i]) matches = false;
      }
      if (matches)
        await jobs.dispatch(current.env, name, Object.values(params)[0]);
    }
  }
}
async function maintenance(cleanupOnly = false) {
  // Recover fanout if a request terminated after its source document commit.
  const cutoff = Date.now() - 15 * 60000;
  if (!cleanupOnly) {
    for (const [collection, time, trigger] of [
      ["sos_alerts", new Date(cutoff).toISOString(), "enqueueSosPush"],
      [
        "placeEvents",
        firestore.Timestamp.fromMillis(cutoff),
        "enqueuePlacePush",
      ],
    ]) {
      const docs = await db
        .collection(collection)
        .where("timestamp", ">=", time)
        .where("pushFanoutPending", "==", true)
        .limit(4)
        .get();
      for (const pending of docs.docs)
        await jobs.dispatch(scope.getStore().env, trigger, pending.id);
    }
    for (const [collection, trigger] of [
      ["sosPushDeliveries", "deliverSosPush"],
      ["placePushDeliveries", "deliverPlacePush"],
      ["accountDeletions", "processAccountDeletion"],
    ]) {
      const limit = collection === "accountDeletions" ? 1 : 6;
      let pendingQuery = db
        .collection(collection)
        .where("status", "==", "pending");
      if (collection !== "accountDeletions")
        pendingQuery = pendingQuery.where(
          "nextAttemptAt",
          "<=",
          firestore.Timestamp.now(),
        );
      const pending = await pendingQuery.limit(limit).get();
      const stalled = await db
        .collection(collection)
        .where("status", "==", "processing")
        .where("leaseUntil", "<=", firestore.Timestamp.now())
        .limit(limit)
        .get();
      for (const doc of [...pending.docs, ...stalled.docs])
        await jobs
          .dispatch(scope.getStore().env, trigger, doc.id)
          .catch(() => {});
    }
    return;
  }
  // Spark has no billed TTL job: bounded cleanup uses ordinary free-quota writes.
  for (const collection of [
    "sosPushDeliveries",
    "placePushDeliveries",
    "pushDevices",
    "accountDeletions",
    "inviteAttempts",
    "circleInvites",
    "placePresence",
    "placeEvents",
    "sos_alerts",
    "points",
  ]) {
    const query =
      collection === "points"
        ? db.collectionGroup(collection)
        : db.collection(collection);
    const docs = await query
      .where(
        collection === "circleInvites" ? "expiresAt" : "expireAt",
        "<=",
        firestore.Timestamp.now(),
      )
      .limit(collection === "points" ? 200 : 10)
      .get();
    if (docs.empty) continue;
    const batch = db.batch();
    for (const doc of docs.docs) batch.delete(doc.ref);
    await batch.commit();
  }
}
export default {
  async fetch(request, env, ctx) {
    const path = new URL(request.url).pathname;
    if (request.method === "GET" && path === "/health")
      return response(
        { status: configured(env) ? "ready" : "configuration-required" },
        configured(env) ? 200 : 503,
      );
    if (request.method === "OPTIONS")
      return new Response(null, { status: 204, headers });
    if (path.startsWith("/_jobs/")) {
      const job = jobs.validJob(request, env);
      if (!job) return response({ error: { status: "UNAUTHENTICATED" } }, 401);
      try {
        return await scoped(env, async () => {
          if (job.name === "processAccountDeletion")
            await accountJobs.process(job.id);
          else
            await backend[job.name]({
              params: {
                [job.name.includes("Sos")
                  ? "alertId"
                  : job.name.includes("Place")
                    ? "eventId"
                    : "deliveryId"]: job.id,
                deliveryId: job.id,
              },
            });
          ctx.waitUntil(createdEvents().catch(() => {}));
          return response({ accepted: true });
        });
      } catch (_) {
        return response({ error: { status: "UNAVAILABLE" } }, 503);
      }
    }
    const name = path.slice(1),
      handler = backend[name];
    if (
      request.method !== "POST" ||
      !Object.hasOwn(backend, name) ||
      handler?.kind !== "callable"
    )
      return response(
        { error: { status: "NOT_FOUND", message: "Unknown operation." } },
        404,
      );
    try {
      const verified = await verifyRequest(request, env);
      const data = await body(request);
      return await scoped(env, async () => {
        const result = await handler({ ...verified, data });
        ctx.waitUntil(
          createdEvents().catch((error) =>
            console.error("Background job deferred", {
              code: error.code || "internal",
            }),
          ),
        );
        return response({ result });
      });
    } catch (error) {
      const code = statusCodes[error.code] ? error.code : "internal";
      const message =
        code === "internal"
          ? "Unable to complete this request."
          : error.name === "Error" && !(error instanceof ApiError)
            ? error.message
            : "Unable to complete this request. Check your account and app configuration.";
      return response(
        { error: { status: code.replaceAll("-", "_").toUpperCase(), message } },
        statusCodes[code] || 500,
      );
    }
  },
  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      scoped(env, () => maintenance(event.cron === "*/30 * * * *")).catch(
        (error) =>
          console.error("Maintenance deferred", {
            code: error.code || "internal",
          }),
      ),
    );
  },
};
