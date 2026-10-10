const { spawnSync } = require("node:child_process");
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!/^127\.0\.0\.1:\d+$/.test(host || ""))
  throw new Error("Local Firestore emulator required");
(async () => {
  for (const file of [
    "membership",
    "sos",
    "invite_rotation",
    "account_deletion",
    "push",
    "place_push",
    "locations",
    "places",
    "resumable",
  ]) {
    const cleared = await fetch(
      `http://${host}/emulator/v1/projects/demo-family-guard/databases/(default)/documents`,
      { method: "DELETE" },
    );
    if (!cleared.ok) throw new Error("Unable to clear demo emulator");
    console.log(`Worker REST integration: ${file}`);
    const result = spawnSync(
      process.execPath,
      [
        "scripts/run-node-tests.cjs",
        "--require",
        "./workers/test/rest-preload.cjs",
        `${file === "resumable" ? "workers/test" : "test"}/${file}.integration.cjs`,
      ],
      { stdio: "inherit" },
    );
    if (result.status !== 0) process.exit(result.status || 1);
  }
})().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
