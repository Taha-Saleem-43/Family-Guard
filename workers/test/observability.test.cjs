const { test } = require("node:test");
const assert = require("node:assert/strict");
const { observation, increment, countFirestoreReads } = require("../src/observability.cjs");
const { estimate } = require("../src/capacity.cjs");
const { health } = require("../../scripts/backend-capacity.cjs");
const { GoogleClient } = require("../src/google.cjs");
const { metrics } = require("../../scripts/worker-metrics.cjs");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");

test("deployment keeps log volume sampled and automatic URL/tracing logs disabled", () => {
  const config = JSON.parse(readFileSync(resolve(__dirname, "../wrangler.jsonc"), "utf8").replace(/,\s*([}\]])/g, "$1"));
  assert.equal(config.observability.enabled, true);
  assert.equal(config.observability.logs.invocation_logs, false);
  assert.equal(config.observability.traces.enabled, false);
  assert.equal(config.observability.issues.enabled, false);
  assert.equal(config.observability.redact_query_string, true);
  assert.ok(config.observability.head_sampling_rate > 0 && config.observability.head_sampling_rate <= 0.1);
  assert.deepEqual(config.triggers.crons, ["* * * * *", "*/30 * * * *"]);
});

test("observation emits a fixed schema and cannot log arbitrary paths, IDs or fields", async () => {
  const records = [];
  let clock = 10;
  const metric = observation("secret-kind", "/_jobs/deliverSosPush/private-user?token=private-token", { clock: () => clock, sink: (value) => records.push(value) });
  await metric.run(async () => {
    increment("googleRequests", 2);
    increment("userId", 42);
    increment("writeAttempts", -10);
    countFirestoreReads("documents:batchGet", { documents: ["private-document", "missing-document"] }, []);
    countFirestoreReads("documents:runQuery", {}, []);
    countFirestoreReads("documents:runQuery", {}, [{ document: {} }, { readTime: "ignored" }]);
  });
  clock = 35;
  metric.finish(503);
  assert.equal(metric.finish(200), null);
  assert.deepEqual(records, [{ event: "familyguard.operation", version: 1, kind: "http", operation: "unknown", status: 503,
    wallMs: 25, googleRequests: 2, firestoreRequests: 0, documentReadsLowerBound: 4,
    writeAttempts: 0, deleteAttempts: 0, jobDispatches: 0, dispatchFailures: 0 }]);
  assert.doesNotMatch(JSON.stringify(records), /private|token|userId/);
});

test("overlapping invocations never share counters or pending I/O", async () => {
  let release;
  const wait = new Promise((resolve) => { release = resolve; });
  const a = observation("http", "createCircle", { sink: () => {} });
  const b = observation("job", "deliverSosPush", { sink: () => {} });
  const first = a.run(async () => { increment("googleRequests"); await wait; increment("googleRequests"); });
  await b.run(async () => { increment("googleRequests", 5); release(); });
  await first;
  assert.equal(a.finish(200).googleRequests, 2);
  assert.equal(b.finish(200).googleRequests, 5);
  assert.doesNotThrow(() => observation("http", "health", { sink: () => { throw new Error("sink unavailable"); } }).finish(200));
});

test("Google instrumentation counts RPCs and attempted writes without recording payloads", async () => {
  const metric = observation("http", "ingestLocations", { sink: () => {} });
  const client = new GoogleClient({}, async (url, options) => {
    const data = JSON.parse(options.body);
    if (url.endsWith(":batchGet")) return new Response(JSON.stringify(data.documents.map((name) => ({ missing: name }))));
    return new Response("{}");
  });
  client.token = async () => "private-token";
  await metric.run(async () => {
    await client.firestore("private-path:batchGet", { documents: ["private-user", "private-circle"] });
    await client.firestore("private-path:commit", { writes: [{ update: { name: "private-user" } }, { delete: "private-point" }] });
  });
  const record = metric.finish(200);
  assert.equal(record.googleRequests, 2);
  assert.equal(record.firestoreRequests, 2);
  assert.equal(record.documentReadsLowerBound, 2);
  assert.equal(record.writeAttempts, 1);
  assert.equal(record.deleteAttempts, 1);
  assert.doesNotMatch(JSON.stringify(record), /private/);
});

test("capacity planning accounts for idle cron reads and flags exhausted targets", () => {
  const small = estimate();
  assert.equal(small.baseline.idleReadsLowerBound, 12000);
  assert.equal(small.baseline.scheduledRequests, 1488);
  assert.equal(small.fixesPerChild, 230);
  assert.equal(small.withinModeledTargets, true);
  const busy = estimate({ children: 10, trackingHours: 24, movingHours: 24 });
  assert.equal(busy.withinModeledTargets, false);
  assert.equal(busy.budgets.historyCleanup.withinTarget, false);
  for (const scenario of [{ children: -1 }, { children: 0.1 }, { movingHours: 25 }, { retryMultiplier: 0.1 }, { fixesPerUpload: 51 }, { billingEnabled: true }]) {
    assert.throws(() => estimate(scenario));
  }
});

test("live health check is bounded to three serial GETs and records no response data", async () => {
  let calls = 0;
  const report = await health(async (url, options) => {
    calls++;
    assert.equal(url, "https://family-guard-api.tahasaleem981.workers.dev/health");
    assert.equal(options.method, "GET");
    assert.equal(options.redirect, "error");
    assert.equal(options.headers, undefined);
    return new Response(JSON.stringify({ status: "ready", secret: "must-not-log" }));
  });
  assert.equal(calls, 3);
  assert.equal(report.samples.every((sample) => sample.ready), true);
  assert.doesNotMatch(JSON.stringify(report), /must-not-log/);
});

test("provider metrics expose only numeric aggregates and preserve unavailable states", async () => {
  const now = new Date("2026-10-30T12:00:00Z");
  const report = await metrics("private-token", { now, fetcher: async (url, options) => {
    assert.equal(url, "https://api.cloudflare.com/client/v4/graphql");
    assert.equal(options.redirect, "error");
    const input = JSON.parse(options.body);
    assert.equal(input.variables.start, "2026-10-30T00:00:00.000Z");
    assert.equal(input.variables.scriptName, "family-guard-api");
    return new Response(JSON.stringify({ data: { viewer: { accounts: [{ workersInvocationsAdaptive: [{
      sum: { requests: 50, errors: 1, subrequests: 100, private: "private-data" }, quantiles: { cpuTimeP50: 100, cpuTimeP99: 500 },
    }] }] } } }));
  } });
  assert.equal(report.requests, 50);
  assert.equal(report.cpuTimeP50Raw, 100);
  assert.equal(report.cpuTimeP50Ms, 0.1);
  assert.equal(report.cpuTimeP99Ms, 0.5);
  assert.doesNotMatch(JSON.stringify(report), /private/);
  const unavailable = await metrics("private-token", { fetcher: async () => new Response(JSON.stringify({ errors: [{ message: "private-data" }] }), { status: 403 }) });
  assert.equal(unavailable.available, false);
  assert.equal(unavailable.requests, undefined);
  assert.doesNotMatch(JSON.stringify(unavailable), /private/);
});
