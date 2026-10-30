const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const account = "e112d2619212aeb06fbe64eece7c4f1b";
const script = "family-guard-api";

// Reuse existing project-local Wrangler auth. Never print/cache/export the token.
// This command makes one read-only analytics query and never requests new scopes.
function existingToken() {
  if (process.env.CLOUDFLARE_API_TOKEN) return process.env.CLOUDFLARE_API_TOKEN;
  const config = readFileSync(resolve(__dirname, "../.cache/cloudflare/.wrangler/config/default.toml"), "utf8");
  const match = /^oauth_token\s*=\s*("[^"\r\n]*")\s*$/m.exec(config);
  if (!match) throw new Error("Existing project-local login required");
  return JSON.parse(match[1]);
}
async function metrics(token, { fetcher = fetch, now = new Date() } = {}) {
  const end = now.toISOString();
  const start = new Date(now);
  start.setUTCHours(0, 0, 0, 0);
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
  const report = await metrics(existingToken());
  console.log(JSON.stringify(report, null, 2));
  if (!report.available) process.exitCode = 1;
}
if (require.main === module) main().catch(() => {
  console.error("Worker metrics unavailable. Verify the existing project-local Wrangler login and analytics access. No permissions or plans were changed.");
  process.exitCode = 1;
});
module.exports = { metrics };
