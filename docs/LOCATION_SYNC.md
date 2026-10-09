# Location ingestion and recovery

Native fixes pass accuracy, coordinate and capture-age checks before entering a private SQLite outbox. Each row carries its original account, circle and capture time. A persisted sharing start time rejects callbacks captured before the current sharing session. Foreground and headless callbacks use the same database; transaction leases coordinate upload batches of at most 50 fixes.

The outbox and native queue each retain at most 5,000 records and seven days. These limits bound storage, so continuous movement during a long outage can lose older history. Sampling persists across process restarts: activity/charging changes, a five-point battery change or crossing 20% triggers a sample; otherwise movement requires 45 seconds and 50 metres, with a three-minute heartbeat. Recovered older fixes can fill history without replacing the sampling watermark.

Captured fixes receive deterministic IDs. SQLite commit precedes removal from the native queue. Backend acknowledgement precedes removal from SQLite. Expired upload leases recover after two minutes; transient failures back off from 15 seconds to 15 minutes. A foreground timer, connectivity events and headless heartbeats retry outstanding work. OS scheduling and force-stop restrictions still apply; this does not guarantee immediate delivery while the app cannot run.

`ingestLocations` checks authenticated account identity, child role, current circle membership and account deletion state inside a Firestore transaction. Retries are idempotent, and reused IDs with different contents fail. History keeps the original timestamp and expires after 30 days. Only a newer fix captured within two minutes updates the live profile; concurrent devices and delayed replay cannot move the live watermark backwards. Equal-time later batches retain the existing position.

Logout and sharing stop erase the account's pending fixes and session. A late retry cannot recreate them. Backup is disabled in the Android manifest. The SQLite file is protected by Android app isolation, not application-level encryption or guaranteed forensic erasure. Device-transfer behaviour requires physical-device validation.

## Deployment

Deploy the `ingestLocations` callable before publishing the matching rules/client. Rules reject direct location, history and live-timestamp writes. Older clients that still use direct batches must upgrade; coordinate this migration before production release. No production deployment was performed during implementation.

## Verification

- `npm run test:locations`: real emulator transactions covering retry deduplication, conflicting IDs, simultaneous writers, offline capture timestamps, invalid input, membership changes and account deletion.
- `cd tool/sqlite_tests; flutter pub get --enforce-lockfile; flutter test`: real SQLite reopen/recovery, competing claims, lease expiry, stale acknowledgements, logout fences, retry backoff and persistent sampling. FFI dependencies belong only to this test package and are absent from the Android app dependency graph.
- Physical Android gates: airplane-mode recovery, swipe-away/reboot headless plugin registration, logout/relogin while uploads are active, circle changes during an outage, clock changes, permission withdrawal, battery consumption and the signed release build. These have not been claimed as passed without a device.
