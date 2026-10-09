# Release status

## Foundations and SOS state correction

Implemented foundations:

- Backend-owned circle creation and invite redemption, atomic membership changes, private invite secrets, seven-day invite expiry, redemption rate limits and circle size bounds.
- Firestore rules for family isolation, immutable client membership/roles, parent-managed places and sender-owned SOS resolution.
- Firebase Auth-backed restoration, logout stops native tracking, display-only session preferences and removal of previously cached JWTs.
- Shared foreground/headless upload entry point, fix validation, serialized atomic live/history writes and removal of upload-time client cleanup.
- Timestamp history expiry fields and TTL configuration; honest empty history and real permission queries.
- Regression tests and GitHub Actions for app, backend and rules verification.
- SOS alert/profile changes use atomic batches. The sender becomes active only after a successful commit, failed resolution preserves the active alert, and failures offer retry feedback. Nullable SOS identifiers clear correctly. This does not implement push delivery, acknowledgement or durable retry after an ambiguous timeout.

## Deployment dependencies — do not deploy independently

The new client requires `createCircle` and `joinCircle` Cloud Functions. Deploy compatible functions/rules/indexes and register App Check together in a controlled staging project first. Release uses Play Integrity; development uses registered App Check debug tokens. Never commit debug tokens or service-account credentials. Functions currently use `us-central1`, matching the client default; review region choice before production.

Existing circle invite codes are not automatically migrated. Existing roles and memberships were writable under the old rules and require an owner-reviewed migration before they can be trusted. Move legacy invite secrets out of public circle documents and issue new private invite records. Do not deploy this ruleset over existing user data without checking this migration.

History readers now query Firestore timestamps. Old string timestamps/expiry fields must be migrated with a backup and a dry run, or explicitly archived as pre-release data after owner approval. TTL must be enabled for `points.expireAt` and `inviteAttempts.expireAt`; it is asynchronous and has billing implications. Permanent user profiles have no TTL.

## Remaining release gates

- Production Firebase/Play Console access, approved permanent package ID, release signing, app-check registration and deployment review.
- Push token lifecycle, backend SOS push fan-out, notification handling independent of the map tab, persisted SOS state and acknowledgement.
- Native geofence transition processing and alerts; do not advertise it as working until tested end to end.
- Durable offline upload queue/coalescing, timestamp/ordering reconciliation, accurate connectivity/freshness reporting and adaptive battery tuning. Current serialization is process-local and does not establish durable recovery by itself.
- History cursor pagination and migration UX. Current query is bounded to 1,000 points; a full pagination interface is still needed.
- Invite rotation/revocation UI before seven-day invites expire, account deletion and membership removal backend flows.
- Android target API/release identity/signing checks, supported-device background/boot/permission-revocation tests and battery benchmarks.
- Privacy policy, prominent background-location disclosure, data-safety declaration, store assets and closed testing.

New personal Play accounts currently require at least 12 opted-in testers continuously for 14 days before applying for production access. See [Google's testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465). A closed-test build is the next-week target; public availability depends on account eligibility and review.

## Verification

Local Flutter suite: 55 tests passed. Dart analysis: no issues. Firestore security emulator: 9 tests passed. Backend domain tests: 3 passed. Membership transaction emulator integration: 6 passed, including concurrent creation, invite expiry, idempotent joining and rate limiting.

These checks do not establish physical-device behavior, Play approval, deployed backend compatibility, or measured battery savings. GitHub Actions only runs remotely after the branch is pushed.

The SOS state correction additionally passed the full 56-test Flutter suite before its failure-path regression was added; all 10 SOS tests then passed, including the added failure-path test. Flutter analysis reported no issues. The initial remote foundation Flutter job passed; its backend job exposed a Node 22 isolation-flag incompatibility, now corrected by a portable launcher and awaiting remote revalidation.
