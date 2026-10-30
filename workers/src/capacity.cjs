// Planning estimates, not measured quotas or a supported launch-size promise.
const { recoveryIds, cleanupCollections, historyPages, historyPageSize } = require("./maintenance.cjs");
const limits = Object.freeze({
  workerRequests: 100000, firestoreReads: 50000, firestoreWrites: 20000,
  firestoreDeletes: 20000, historyCleanup: 48 * historyPages * historyPageSize,
});
const defaults = Object.freeze({
  children: 3, trackingHours: 8, movingHours: 1,
  movingIntervalSeconds: 45, stationaryIntervalSeconds: 180,
  extraFixesPerChild: 10, fixesPerUpload: 1,
  listenerReadsPerFix: 2, retryMultiplier: 1.1,
  extraWorkerRequests: 1000, extraReads: 2000, extraWrites: 1000,
  extraDeletes: 1000, headroom: 0.3,
});
function estimate(input = {}) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error("Provide a scenario object.");
  for (const key of Object.keys(input)) if (!Object.hasOwn(defaults, key)) throw new Error(`Unknown scenario field: ${key}`);
  const scenario = { ...defaults, ...input };
  for (const [key, value] of Object.entries(scenario)) {
    if (!Number.isFinite(value) || value < 0 || value > 10000000) throw new Error(`Invalid scenario field: ${key}`);
  }
  for (const key of ["children", "extraFixesPerChild", "fixesPerUpload", "listenerReadsPerFix", "extraWorkerRequests", "extraReads", "extraWrites", "extraDeletes"]) {
    if (!Number.isSafeInteger(scenario[key])) throw new Error(`Use an integer for ${key}.`);
  }
  if (scenario.trackingHours > 24 || scenario.movingHours > scenario.trackingHours || scenario.headroom >= 1 ||
      scenario.retryMultiplier < 1 || scenario.movingIntervalSeconds < 1 || scenario.stationaryIntervalSeconds < 1 ||
      scenario.fixesPerUpload < 1 || scenario.fixesPerUpload > 50) throw new Error("Invalid tracking, retry, batch or headroom assumption.");
  const cleanupPartitions = cleanupCollections.length + historyPages - 1;
  // Include both cron coordinators AND every signed child invocation.
  const scheduledRequests = 1440 * (1 + recoveryIds.length) + 48 * (1 + cleanupPartitions);
  const idleReadsLowerBound = 1440 * 8 + 48 * cleanupPartitions;
  const fixesPerChild = Math.ceil(scenario.movingHours * 3600 / scenario.movingIntervalSeconds +
    (scenario.trackingHours - scenario.movingHours) * 3600 / scenario.stationaryIntervalSeconds) + scenario.extraFixesPerChild;
  const fixes = scenario.children * fixesPerChild;
  const uploads = scenario.children * Math.ceil(fixesPerChild / scenario.fixesPerUpload);
  // Warm configured geofences: profile/circle/deletion/config/presence reads,
  // plus history dedup reads. Each upload writes history/profile/presence.
  const daily = {
    workerRequests: scheduledRequests + Math.ceil(uploads * scenario.retryMultiplier) + scenario.extraWorkerRequests,
    firestoreReads: idleReadsLowerBound + Math.ceil((uploads * 5 + fixes) * scenario.retryMultiplier) +
      fixes * scenario.listenerReadsPerFix + scenario.extraReads,
    firestoreWrites: Math.ceil((fixes + uploads * 2) * scenario.retryMultiplier) + scenario.extraWrites,
    firestoreDeletes: fixes + scenario.extraDeletes,
    historyCleanup: fixes,
  };
  const budgets = Object.fromEntries(Object.entries(limits).map(([key, limit]) => [key, {
    estimated: daily[key], limit, target: Math.floor(limit * (1 - scenario.headroom)),
    percent: Math.round(1000 * daily[key] / limit) / 10,
    withinTarget: daily[key] <= Math.floor(limit * (1 - scenario.headroom)),
  }]));
  return {
    type: "scenario-estimate-not-production-measurement", scenario,
    baseline: { scheduledRequests, idleReadsLowerBound },
    fixesPerChild, dailyFixes: fixes, dailyUploads: uploads, budgets,
    withinModeledTargets: Object.values(budgets).every((value) => value.withinTarget),
    unmeasured: ["Worker CPU and peak subrequests", "Firestore index/rules charges and reconnect reads",
      "Data storage/index sizes and monthly bandwidth", "Auth/App Check/FCM quotas",
      "Per-collection cleanup backlogs, bursts, geofence fanout and transaction contention"],
  };
}
module.exports = { estimate, defaults, limits };
