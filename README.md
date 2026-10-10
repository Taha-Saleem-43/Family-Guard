# Family Guard

Family Guard is a Flutter/Firebase app for consent-based family location sharing, place activity and SOS alerts. Parents can view their circle's member locations and history and manage places; children share their own location after disclosure and permission setup. Roles and membership are assigned by authenticated backend operations.

## Engineering status

The active backend uses **Firebase Spark + Cloudflare Workers Free**. See the
[free backend guide](workers/README.md) for local verification, credential setup,
deployment and capacity limits. Keep Firebase billing disabled and use
`firebase.spark.json` when deploying Firestore rules and indexes.

This repository contains the secured engineering baseline and [UI refinements](docs/UI_REFINEMENTS.md) for navigation, map status, role-specific controls and recovery screens. Production deployment, owner signing, signed AAB/device acceptance, measured battery/capacity testing and Play submission remain release gates. See [the release runbook](docs/RELEASE_RUNBOOK.md) for configuration, deployment order and acceptance checks.

The app does not guarantee continuous location availability or instant emergency notification. Android permissions, connectivity, notification settings and device restrictions affect delivery and freshness. Unknown and stale member status is displayed explicitly.

## Implemented behavior

- Email/password authentication with server-verified profiles and account/session fences. Parent and child roles cannot be changed through a client preview toggle.
- Atomic circle creation/joining, parent-only private invite management, expiring random invites, redemption rate limits and a twenty-member circle limit. Viewing peers requires actual membership in the current roster.
- FlutterMap member views with captured timestamps, movement and battery status. New membership clears old live location; history retains its original circle scope.
- Consent scoped to the account, sign-in and circle. Child sharing requires disclosure and location permissions; parent setup requests notifications without child location prompts.
- Balanced Tracelet tracking with motion-aware sampling, bounded native retention and a durable SQLite outbox shared with headless execution. Recovery uploads use deterministic point IDs and preserve capture times.
- Server-owned location ingestion, freshness watermarks and cursor-based history. Delayed recovery does not overwrite newer live fixes.
- Parent-managed places with bounded configuration, hysteresis and confirmed arrival/departure transitions. Private push queues notify parents of place activity.
- Idempotent SOS creation/resolution, shared alert presentation and scoped dismissals. Durable push queues distinguish FCM acceptance, receipt and opening; notification payloads omit private coordinates and names.
- Reauthenticated account deletion with durable backend cleanup/retries and scoped local cleanup. Verification/circle failures retain account management controls.

## Repository structure

```text
lib/
  core/                 Shared models, services, providers, privacy and theme
  features/
    auth/               Authentication and account services
    onboarding/         Circle setup, disclosure and permissions
    map/                Member map presentation
    history/            Paged location history
    places/             Place management
    alerts/             Activity feed
    sos/                Emergency sender/receiver presentation
    settings/           Account, circle and permission controls
    home/               Main shell and navigation
functions/
  features/             Account, circle, location, place, push and SOS handlers
  test/                 Backend domain tests
workers/
  src/                  Free backend transport, identity verification and REST adapter
  test/                 Security, runtime and REST feature verification
 test/                  Flutter tests and Firebase emulator integration tests
 tool/sqlite_tests/     Separate real-SQLite verification package
 scripts/               Test runner and Android native alignment verification
 docs/                  Lifecycle, privacy, feature and release documentation
 .github/workflows/     Automated verification
```

## Development and verification

Use Flutter **3.41.7**, the checked-in dependency locks and Node **22** for backend parity with CI. Keep new packages/caches project-local; do not install tools globally. Use the existing SDK or an isolated local toolchain. The nested SQLite package has its own test-only dependency graph.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --coverage

# In tool/sqlite_tests:
flutter pub get --enforce-lockfile
flutter test

# From the repository root, with the local Firebase CLI on PATH:
npm ci --ignore-scripts
npm ci --prefix functions --ignore-scripts
npm run test:backend
npm run test:rules
npm run test:membership
npm run test:sos
npm run test:invites
npm run test:accounts
npm run test:push
npm run test:locations
npm run test:places
```

Firebase integration tests use the `demo-family-guard` Firestore emulator. They must not target production. Keep concurrent test runs isolated so fixtures do not share an emulator accidentally.

CI runs on pull requests and `main`, `taha/**` and `release/**` pushes. It verifies Flutter analysis/tests, real SQLite recovery, Firebase rules/handlers and an ARM64 Android debug build. Android checks inspect native/ZIP 16 KB alignment, reject unused exact-alarm permissions in the merged APK and reject an unconfigured production identity. A debug APK passing CI does not validate a signed release AAB or real-device behavior.

Feature work uses `taha/<feature>` branches and focused commits. Integrate stacked branches once at the final passing head, preserving feature history. Never commit signing keys, credentials or production debug tokens.

## Detailed documentation

- [Android release configuration](docs/ANDROID_RELEASE.md)
- [Release operations and acceptance gates](docs/RELEASE_RUNBOOK.md)
- [Consent](docs/SHARING_CONSENT.md) and [permission lifecycle](docs/PERMISSIONS.md)
- [Tracking lifecycle](docs/TRACKING_LIFECYCLE.md) and [sampling/battery measurement](docs/TRACKING_EFFICIENCY.md)
- [Durable location synchronization](docs/LOCATION_SYNC.md) and [live account boundaries](docs/LIVE_ACCOUNT_SCOPE.md)
- [SOS push delivery](docs/SOS_PUSH.md) and [place transitions/notifications](docs/PLACE_EVENTS.md)
- [Account deletion](docs/ACCOUNT_DELETION.md)
