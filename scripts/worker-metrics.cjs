const { spawnSync } = require("node:child_process");
const { resolve } = require("node:path");
const account = "e112d2619212aeb06fbe64eece7c4f1b";
const script = "family-guard-api";

// Reuse existing project-local Wrangler auth. Never print/cache/export the token.
// This command makes one read-only analytics query and never requests new scopes.
function existingToken({ run = spawnSync, env = process.env } = {}) {
  if (env.CLOUDFLARE_API_TOKEN) return env.CLOUDFLARE_API_TOKEN;
  // Wrangler may use the OS keychain, not the legacy plaintext cache. Capture
  // its supported command in a pipe; never inherit stdout/stderr or log them.
  const result = run(process.execPath, [resolve(__dirname, "../workers/node_modules/wrangler/bin/wrangler.js"), "auth", "token", "--json"], {
    cwd: resolve(__dirname, "../workers"), encoding: "utf8", timeout: 30000,
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...env, XDG_CONFIG_HOME: resolve(__dirname, "../.cache/cloudflare"), WRANGLER_SEND_METRICS: "false" },
  });
  let credential;
  try { if (result.status === 0) credential = JSON.parse(result.stdout); } catch (_) { /* Never print token-bearing parse errors. */ }
  if (typeof credential?.token !== "string" || !credential.token) throw new Error("Existing Wrangler credential unavailable");
  return credential.token;
}
async function metrics(token, { fetcher = fetch, now = new Date(), since } = {}) {
  const end = now.toISOString();
  const start = since === undefined ? new Date(now) : new Date(since);
  if (since === undefined) start.setUTCHours(0, 0, 0, 0);
  if (!Number.isFinite(start.getTime()) || start > now || now - start > 86400000) throw new Error("Metrics window must be within the last 24 hours");
  const result = await fetcher("https://api.cloudflare.com/client/v4/graphql", {
    method: "POST", redirect: "error", signal: AbortSignal.timeout(15000),
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      query: `query Metrics($accountTag: string!, $start: string!, $end: string!, $scriptName: string!) {
        viewer { accounts(filter: {accountTag: $accountTag}) {
          workersInvocationsAdaptive(limit: 1, filter: {scriptName: $scriptName, datetime_geq: $start, datetime_leq: $end}) {
            sum { requests errors subrequests }
            quantiles { cpuTimeP50 cpuTimeP99 }
          }
        }}
      }`,
      variables: { accountTag: account, scriptName: script, start: start.toISOString(), end },
    }),
  });
  const data = await result.json();
  const rows = data.data?.viewer?.accounts?.[0]?.workersInvocationsAdaptive;
  if (!result.ok || data.errors?.length || !Array.isArray(rows)) {
    // Do not log provider errors/headers: they can contain sensitive context.
    return { available: false, reason: "Analytics unavailable with the existing login or query. Use the provider dashboard; no permissions were changed." };
  }
  if (rows.length === 0) return { available: true, start: start.toISOString(), end, hasData: false };
  const row = rows[0];
  const number = (value) => Number.isFinite(value) && value >= 0 ? value : null;
  return {
    available: true, start: start.toISOString(), end, hasData: true,
    requests: number(row.sum?.requests), errors: number(row.sum?.errors), subrequests: number(row.sum?.subrequests),
    // Units verified from Cloudflare's live GraphQL schema on 2026-10-30:
    // AccountWorkersInvocationsAdaptiveQuantiles CPU fields are microseconds.
    cpuTimeP50Raw: number(row.quantiles?.cpuTimeP50), cpuTimeP99Raw: number(row.quantiles?.cpuTimeP99),
    cpuTimeP50Ms: number(row.quantiles?.cpuTimeP50) === null ? null : row.quantiles.cpuTimeP50 / 1000,
    cpuTimeP99Ms: number(row.quantiles?.cpuTimeP99) === null ? null : row.quantiles.cpuTimeP99 / 1000,
    caveat: "Adaptive analytics for this Worker, not account-wide billing, a load test, or per-invocation CPU maximum. Free-tier reference: 10 ms CPU per invocation; network wait is separate.",
  };
}
async function main() {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 2 || args[0] !== "--since")) throw new Error("Use --since with an ISO timestamp");
  const report = await metrics(existingToken(), { since: args[1] });
  console.log(JSON.stringify(report, null, 2));
  if (!report.available) process.exitCode = 1;
}
if (require.main === module) main().catch(() => {
  console.error("Worker metrics unavailable. Verify the existing project-local Wrangler login and analytics access. No permissions or plans were changed.");
  process.exitCode = 1;
});
module.exports = { metrics, existingToken };
