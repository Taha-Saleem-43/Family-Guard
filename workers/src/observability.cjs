const { AsyncLocalStorage } = require("node:async_hooks");

// Only fixed operation names and numeric counters may enter custom logs.
// Never accept request URLs, IDs, error messages, tokens or document fields.
const storage = new AsyncLocalStorage();
const operations = new Set([
  "health", "preflight", "unknown", "invalidJob", "createdEvents",
  "recovery", "cleanup", "ingestLocations", "savePlace", "deletePlace",
  "togglePlaceNotifications", "triggerSos", "resolveSos", "rotateCircleInvites",
  "requestAccountDeletion", "registerPushDevice", "unregisterPushDevice",
  "acknowledgeSosPush", "acknowledgePlacePush", "createCircle", "joinCircle",
  "enqueueSosPush", "enqueuePlacePush", "deliverSosPush", "deliverPlacePush",
  "processAccountDeletion",
  "recoverMaintenance", "cleanupExpired", "leaveCircle",
]);
const kinds = new Set(["http", "job", "background", "maintenance"]);
const counterNames = [
  "googleRequests", "firestoreRequests", "documentReadsLowerBound",
  "writeAttempts", "deleteAttempts", "jobDispatches", "dispatchFailures",
];

function increment(name, count = 1) {
  const current = storage.getStore();
  if (current && counterNames.includes(name) && Number.isSafeInteger(count) && count >= 0)
    current.counters[name] += count;
}

function observation(kind, operation, { clock = Date.now, sink = (value) => console.log(value) } = {}) {
  const started = clock();
  const counters = Object.fromEntries(counterNames.map((name) => [name, 0]));
  let finished = false;
  return {
    run: (callback) => storage.run({ counters }, callback),
    finish(status) {
      if (finished) return null;
      finished = true;
      const record = {
        event: "familyguard.operation", version: 1,
        kind: kinds.has(kind) ? kind : "http",
        operation: operations.has(operation) ? operation : "unknown",
        status: Number.isInteger(status) && status >= 100 && status <= 599 ? status : 500,
        wallMs: Math.min(3600000, Math.max(0, Math.round(clock() - started) || 0)),
        ...counters,
      };
      // Monitoring must never change application success/failure semantics.
      try { sink(record); } catch (_) { /* Ignore unavailable logging sinks. */ }
      return record;
    },
  };
}

async function observed(kind, operation, callback) {
  const metric = observation(kind, operation);
  return metric.run(async () => {
    try {
      const result = await callback();
      metric.finish(result instanceof Response ? result.status : 200);
      return result;
    } catch (error) {
      metric.finish(500);
      throw error;
    }
  });
}

function countFirestoreReads(path, input, output) {
  if (path.endsWith(":batchGet")) {
    increment("documentReadsLowerBound", input?.documents?.length ?? 0);
  } else if (path.endsWith(":runQuery")) {
    // Minimum per-query billing includes empty queries. Index scans, rules,
    // listeners and dashboard activity are NOT represented by this estimate.
    const count = Array.isArray(output) ? output.filter((row) => row.document).length : 0;
    increment("documentReadsLowerBound", Math.max(1, count));
  }
}

module.exports = { observation, observed, increment, countFirestoreReads };
