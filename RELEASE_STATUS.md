# Release status

## Foundations and SOS state correction

Implemented foundations:

- Backend-owned circle creation and invite redemption, atomic membership changes, private invite secrets, seven-day invite expiry, redemption rate limits and circle size bounds.
- Parents can replace both invite codes atomically from settings; previous codes stop working and existing memberships remain unchanged. Expiry comes from the private server record. Private code fields clear on user/circle/role changes, and each subscription generation rejects stale callbacks.
- Firestore rules for family isolation, immutable client membership/roles, parent-managed places and sender-owned SOS resolution.
- Firebase Auth-backed restoration, logout stops native tracking, display-only session preferences and removal of previously cached JWTs.
- Shared foreground/headless upload entry point, fix validation, serialized atomic live/history writes and removal of upload-time client cleanup.
- Timestamp history expiry fields and TTL configuration; honest empty history and real permission queries.
- History query failures propagate to a retryable error panel; loading and empty data have separate states. Refresh waits for the query and works with short or empty lists. History member selection resets across account/circle changes, and children query only their own history. History map controllers are disposed with their screen.
- Location-bearing profiles are readable only by their owner or a parent in the same circle. Child subscriptions read one profile; parent subscriptions retain the family roster. Role changes restart subscriptions and stale callbacks are rejected.
- Regression tests and GitHub Actions for app, backend and rules verification.
- Android targets API 36 with explicit build tools and SDK download controls. Release builds no longer use debug signing; a validation task requires an owner-approved application ID and local upload-keystore configuration. Native debug compilation and release-guard checks were added to branch CI; branch CI has passed native debug compilation and release-guard verification.
- SOS creation/resolution use authenticated, App Check protected backend transactions. Sender identity and names come from the server profile. Concurrent sends create one active alert per user; persistent request IDs make ambiguous timeout retries safe across client recreation. Resolved request IDs cannot reopen an old alert, and resolving an old alert cannot clear a newer one. Client writes to SOS records and profile flags are denied.
- Emergency handling remains mounted above every app tab. Confirmed server snapshots restore the sender's active alert and its original duration; server resolution clears it. Repeated snapshots sound each receiver alert once per session. Receiver dismissals persist per account/circle with a 100-ID bound. Account changes invalidate stale callbacks, and subscription errors retain confirmed state and show an update warning. Stale cached coordinates are omitted from SOS sends. History is bounded to the newest 100 alerts. Offline restart restoration remains unfinished.

## Deployment dependencies — do not deploy independently

The new client requires `createCircle`, `joinCircle`, `triggerSos`, `resolveSos` and `rotateCircleInvites` Cloud Functions. Deploy compatible functions/rules/indexes and register App Check together in a controlled staging project first. Release uses Play Integrity; development uses registered App Check debug tokens. Never commit debug tokens or service-account credentials. Functions currently use `us-central1`, matching the client default; review region choice before production.

Existing circle invite codes are not automatically migrated. Existing roles and memberships were writable under the old rules and require an owner-reviewed migration before they can be trusted. Move legacy invite secrets out of public circle documents and issue new private invite records. Do not deploy this ruleset over existing user data without checking this migration.

History readers now query Firestore timestamps. Old string timestamps/expiry fields must be migrated with a backup and a dry run, or explicitly archived as pre-release data after owner approval. TTL must be enabled for `points.expireAt`, `inviteAttempts.expireAt`, `circleInvites.expiresAt` and `sos_alerts.expireAt` (set only after resolution; active emergencies do not expire silently); it is asynchronous and has billing implications. Permanent user profiles have no TTL.

## Remaining release gates

- Production Firebase/Play Console access, approved permanent package ID, release signing, app-check registration and deployment review.
- Push token lifecycle, backend SOS push fan-out, background notification handling, durable offline SOS state restoration and delivery acknowledgement.
- Native geofence transition processing and alerts; do not advertise it as working until tested end to end.
- Durable offline upload queue/coalescing, timestamp/ordering reconciliation, accurate connectivity/freshness reporting and adaptive battery tuning. Current serialization is process-local and does not establish durable recovery by itself.
- History cursor pagination and migration UX. Current query is bounded to 1,000 points; a full pagination interface is still needed.
- Account deletion and membership removal backend flows.
- Android target API/release identity/signing checks, supported-device background/boot/permission-revocation tests and battery benchmarks.
- Privacy policy, prominent background-location disclosure, data-safety declaration, store assets and closed testing.

New personal Play accounts currently require at least 12 opted-in testers continuously for 14 days before applying for production access. See [Google's testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465). A closed-test build is the next-week target; public availability depends on account eligibility and review.

## Verification

Profile validation: all 76 Flutter tests pass, analysis reports no issues, and all 11 Firestore rules tests pass. Client updates validate display-name length, battery bounds, charging type, speed, activity and last-seen type. Legacy malformed account fields no longer crash restoration; Firestore and ISO creation timestamps are supported.

Location access hardening: Flutter analysis is clean, all 74 Flutter tests pass, and all 10 Firestore rules emulator tests pass, including child access denial for parent/sibling profiles and parent roster query access.

Circle management: 74 Flutter tests passed; invite rotation passed 4 backend emulator tests. Final Flutter analysis reported no issues. Android branch CI built and archived the ARM64 debug APK, rejected an unconfigured release and passed Flutter/Firebase checks. This is a development artifact, not a signed production release.

History reliability: full 71-test Flutter suite passed; final UI changes are checked with the 11 history regressions. Final history analysis reported no issues. Latest remote Flutter and Firebase jobs passed on the Android feature branch; native debug compilation and release-guard verification also passed.

Local Flutter suite: 55 tests passed. Dart analysis: no issues. Firestore security emulator: 9 tests passed. Backend domain tests: 3 passed. Membership transaction emulator integration: 6 passed, including concurrent creation, invite expiry, idempotent joining and rate limiting.

These checks do not establish physical-device behavior, Play approval, deployed backend compatibility, or measured battery savings. GitHub Actions only runs remotely after the branch is pushed.

The SOS state and restoration changes passed the full 67-test Flutter suite and final Flutter analysis with no issues. Regressions cover failed sending/resolution, nullable fields, restored sender alerts, subscription errors, receiver deduplication, same-circle account changes, late send completion, emergencies across content changes, persistent dismissed alerts and timeout-safe requests. SOS backend transactions passed 6 emulator tests; updated security rules passed 9 tests. Foundation GitHub Actions passed both Flutter and Firebase jobs after a portable launcher corrected a Node 22 test-isolation flag incompatibility. Both earlier draft pull requests were closed at the owner's request; verification now runs on feature branch pushes without opening pull requests.
