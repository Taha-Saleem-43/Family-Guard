const { readFileSync } = require("node:fs");
const { performance } = require("node:perf_hooks");
const { estimate } = require("../workers/src/capacity.cjs");

// Offline by default. The only live option makes exactly three unauthenticated,
// serial GETs to our existing health endpoint: no test users or Firestore access.
async function health(fetcher = fetch, clock = () => performance.now()) {
  const samples = [];
  for (let index = 0; index < 3; index++) {
    const start = clock();
    try {
      const result = await fetcher("https://family-guard-api.tahasaleem981.workers.dev/health", {
        method: "GET", redirect: "error", signal: AbortSignal.timeout(15000),
      });
      const body = await result.json();
      samples.push({ status: result.status, ready: result.ok && body.status === "ready", wallMs: Math.round(clock() - start) });
    } catch (_) {
      samples.push({ status: 0, ready: false, wallMs: Math.round(clock() - start) });
    }
  }
  return { type: "health-only-not-authenticated-latency-or-load-test", samples };
}
async function main(args) {
  if (args[0] === "--live-health" && args.length === 1) {
    const report = await health();
    console.log(JSON.stringify(report, null, 2));
    if (report.samples.some((sample) => !sample.ready)) process.exitCode = 1;
    return;
  }
  if (args.length > 1 || args[0]?.startsWith("--")) throw new Error("Usage: node scripts/backend-capacity.cjs [scenario.json | --live-health]");
  const report = estimate(args.length ? JSON.parse(readFileSync(args[0], "utf8")) : {});
  console.log(JSON.stringify(report, null, 2));
  if (!report.withinModeledTargets) process.exitCode = 2;
}
if (require.main === module) main(process.argv.slice(2)).catch(() => {
  console.error("Capacity check failed. Check scenario fields or endpoint availability; no credentials are required.");
  process.exitCode = 1;
});
module.exports = { health };
