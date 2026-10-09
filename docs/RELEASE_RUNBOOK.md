# Release operations

## Current engineering baseline

The feature branches are stacked: the latest branch includes its predecessors. Do not merge each stacked branch independently into main. Integrate the final verified head once, retaining the individual feature commits. No production deployment, signed release bundle, real-device battery measurement or Play submission has been performed.

Automated verification covers Firebase authority and membership, invite limits, SOS idempotency, account deletion, private push delivery, durable location ingestion, place transitions, account/permission lifecycle, device consent and real SQLite recovery. Android CI builds an ARM64 debug APK, checks native/ZIP 16 KB alignment and rejects an unconfigured production identity. These checks do not verify a signed AAB or Android runtime behaviour.

## Configuration gates

- Confirm the permanent Android application ID and register that exact identity in the intended Firebase project. Replace development Firebase configuration together; keep Dart and Android configuration consistent.
- Supply a real upload keystore locally using `android/key.properties`. Preserve a secure independent backup. The release build must pass `validateReleaseConfiguration` and signing validation.
- Configure production App Check/Play Integrity, FCM and required backend IAM in staging first. Verify callable requests from the signed app and headless execution. Debug App Check tokens must not be treated as production setup.
- Complete the Play Console account, privacy-policy/account-deletion pages, store listing, disclosures and applicable testing/review requirements before scheduling publication.

## Staging deployment order

Use the existing local Firebase CLI and project-local dependency caches. Choose the intended project explicitly; the checked-in development identity is not approval to deploy there. Production deployment requires a reviewed target and configuration.

1. Audit existing profiles, memberships, places and history before changing access. The place configuration bootstrap supports at most fifty valid places per circle. Malformed or over-capacity legacy records require review. Do not assign a missing historical circle from a user's current circle: membership may have changed since capture.
2. Deploy the matching callables and triggers, including `ingestLocations`, place management, device registration, both push queues and account deletion. Ingestion now requires the authenticated sign-in's `sharingStartedAt`; old direct-write clients are incompatible.
3. Deploy indexes and verify every index is ready. Explicitly verify TTL policies: history/place presence/events thirty days, push delivery jobs two days, device registrations thirty days and completed deletion jobs two days. TTL removal is asynchronous.
4. Exercise the signed staging client against deployed endpoints. Verify App Check, server permissions, device token registration, offline recovery and delivery acknowledgements.
5. Publish matching rules only with the matching client rollout/upgrade plan. A rollback to old direct-write clients requires a reviewed migration; do not weaken the new access rules to make old writes succeed.

## Operational acceptance

Set project budgets and alerts using the owner's chosen limits. Track callable errors/latency, ingestion rate limiting, Firestore reads/writes, push pending age and expired/failed jobs, and deletion retries. Alert on stalled deletion work and sustained queue backlog. Keep diagnostic payloads free of coordinates, invite codes, device tokens and credentials.

Use bounded staging load tests before claiming production capacity. Include twenty-member circles, ten device registrations per account, simultaneous fifty-point recovery batches and parent place edits during ingestion. Measure transaction retries, p95 latency, cost per recovered batch and queue age. Do not load-test production without a reviewed traffic/cost limit. Max-instance settings and bounded batches constrain work; they are not capacity measurements.

## Device acceptance

Test the actual signed release build on supported phones and a 16 KB runtime:

- First install and upgrade with existing Android grants; child disclosure must precede sharing and parent onboarding must avoid location prompts.
- Foreground, background, swipe-away, reboot and force-stop; check real tracking notices and plugin registration.
- Airplane mode, reconnect and process restart; recovered fixes keep capture times and do not overwrite newer live locations.
- Logout/relogin/account or circle change while fixes and uploads are pending; old data and notifications must not open the replacement account.
- Permission withdrawal/restoration, clock changes, battery saver and OEM restrictions.
- Actual FCM delivery, token rotation, denied notifications, delayed/resolved SOS and parent-only place activity. FCM acceptance alone is not receipt.
- Stationary and moving battery/accuracy measurements described in `TRACKING_EFFICIENCY.md`.

## Integration and publication

Require green CI for the final commit before integrating the stacked work. Build and inspect the owner-signed AAB, verify its certificate and native libraries, complete the device/staging gates, and use the Play Console test/release workflow. UI redesign follows the engineering baseline; it must preserve disclosure, account boundaries and error/retry behaviour.
