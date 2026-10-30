const { createHmac, timingSafeEqual } = require("node:crypto");
const { increment } = require("./observability.cjs");
const { recoveryIds, legacyRecoveryIds, cleanupCollections } = require("./maintenance.cjs");
const allowed = new Set([
  "enqueueSosPush",
  "enqueuePlacePush",
  "deliverSosPush",
  "deliverPlacePush",
  "processAccountDeletion",
  "recoverMaintenance",
  "cleanupExpired",
]);
const endpoint = "https://family-guard-api.tahasaleem981.workers.dev";
function signature(env, path, time) {
  return createHmac("sha256", env.GOOGLE_SERVICE_ACCOUNT)
    .update(time + "\n" + path)
    .digest("hex");
}
function validJob(request, env) {
  const path = new URL(request.url).pathname;
  const [, prefix, name, id] = path.split("/");
  if (
    request.method !== "POST" ||
    prefix !== "_jobs" ||
    !allowed.has(name) ||
    !id ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(id) ||
    (name === "recoverMaintenance" && !recoveryIds.includes(id) && !legacyRecoveryIds.includes(id)) ||
    (name === "cleanupExpired" && !cleanupCollections.includes(id)) ||
    path !== `/_jobs/${name}/${id}`
  )
    return null;
  const time = request.headers.get("X-Job-Time"),
    given = request.headers.get("X-Job-Signature");
  if (
    !/^\d{13}$/.test(time || "") ||
    Math.abs(Date.now() - Number(time)) > 60000 ||
    !/^[a-f0-9]{64}$/.test(given || "") ||
    !env.GOOGLE_SERVICE_ACCOUNT
  )
    return null;
  if (
    !timingSafeEqual(
      Buffer.from(given, "hex"),
      Buffer.from(signature(env, path, time), "hex"),
    )
  )
    return null;
  return { name, id };
}
async function dispatch(env, name, id) {
  if (!allowed.has(name) || !/^[A-Za-z0-9_-]{1,128}$/.test(id))
    throw new Error("Invalid background job");
  const path = `/_jobs/${name}/${id}`,
    time = String(Date.now());
  increment("jobDispatches");
  try {
    const result = await fetch(endpoint + path, {
      method: "POST",
      headers: {
        "X-Job-Time": time,
        "X-Job-Signature": signature(env, path, time),
      },
      signal: AbortSignal.timeout(25000),
    });
    await result.body?.cancel();
    if (!result.ok) throw new Error("Background job remains pending");
  } catch (error) {
    increment("dispatchFailures");
    throw error;
  }
}
module.exports = { validJob, dispatch };
