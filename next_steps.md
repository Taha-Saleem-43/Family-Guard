# FamilyGuard — handoff and next steps

Updated: 13 October 2026. Read this first when continuing in a new chat.

## Goal and owner preferences

Ship a reliable, appealing Android family-location app on Google Play. Keep the backend on free plans; never enable billing, paid services or subscriptions without explicit approval. Free plans have finite capacity, so do not promise unlimited scale.

- Use feature branches named `taha/<feature>`; do not use `codex/`.
- Keep changes structured and run relevant regression tests. CI runs on `taha/**` pushes.
- Commit and push completed feature work. PRs are allowed if helpful, but routine work does not need one.
- Use existing SDKs and project-local dependencies/caches. Do not install packages globally.
- Proceed autonomously with authorized engineering and UI work; ask only for missing owner decisions or genuinely necessary approval.
- Never expose credentials, commit secrets, send real SOS notifications during demos, or delete real account data as part of routine tests.

## Exact Git state

- Workspace: `D:\Flutter_Projects\Others\Family-Guard`.
- Current branch: `taha/offline-map-polish`, based on `taha/password-recovery`.
- Latest app commit: `e5b15c2` — bundle offline fonts, persist viewed map tiles, unify attribution and improve accessible place editing.
- Remote main observed locally: `ebc00d4` — UI accessibility refinements.
- Current branch contains the newer Workers backend, onboarding and map work. Integrate the final verified head once; do not independently merge every stacked predecessor branch.
- Historical CI for `1ccc451`: **Android, Flutter and Firebase/backend jobs all passed**. New branch CI must be checked after pushing; do not treat the historical run as evidence for newer code.
- CI evidence: https://github.com/Taha-Saleem-43/Family-Guard/actions/runs/38085743389
- Documentation-only commits follow that tested app commit. `next_steps.md` is the single maintained guide; the root README links here.

## Implemented

- Firebase email/password accounts, session restoration and account-switch safeguards.
- Parent/child roles, circles, private expiring invites and invite rotation.
- Child sharing disclosure/consent, permission handling and tracking lifecycle boundaries.
- Background location engine, validated fixes, durable SQLite upload queue, retries and offline recovery.
- Family map, location age/accuracy, stale movement handling, paginated location history.
- Places/geofences, activity events, SOS state and push-delivery pipeline.
- Reauthenticated account deletion with resumable server cleanup and local cleanup.
- Account/circle isolation through security rules and trusted backend operations.
- Interactive onboarding with map/place/SOS demos, a bundled silent six-second animation video, reduced-motion support, and new Android/iOS icons.
- Member details now show one **Directions in Google Maps** action for another member viewed by a parent. Self-location uses **Open in Google Maps**. Missing locations have no action; stale warnings remain visible.
- Main map OpenStreetMap credit is a compact linked footer rather than a feature-looking side button. Required attribution must not be removed.

Implementation and emulator tests do not establish real-phone background reliability or production delivery.

## Free backend — already deployed, do not redo provisioning

- Worker: `family-guard-api`.
- Endpoint: https://family-guard-api.tahasaleem981.workers.dev
- Cloudflare account: `e112d2619212aeb06fbe64eece7c4f1b`.
- Firebase project: `familyguard-v2-app` (project number `160141197240`).
- Firebase retains Auth, Firestore listeners and FCM. Trusted callable operations run on Workers through `lib/core/services/backend_functions.dart`.
- Worker configuration: `workers/wrangler.jsonc`; app endpoint override: `FAMILY_GUARD_API_URL`.
- Dedicated identity: `familyguard-worker@familyguard-v2-app.iam.gserviceaccount.com`.
- Approved roles: datastore.user, firebaseauth.admin, firebasecloudmessaging.admin.
- Owner explicitly approved provisioning and transferring its key to encrypted Worker secret `GOOGLE_SERVICE_ACCOUNT`. This is complete. Do not create another key or save/export its value.
- All 14 composite indexes and the history expiry collection-group index were verified ready. Firebase billing was verified disabled during deployment.
- Deploy Firestore using **`firebase.spark.json`**. The older Firebase configuration contains paid Functions/TTL paths; do not use it for this free deployment.
- Free cron cleanup replaces paid TTL. Signed internal HTTP jobs split background work across invocations.
- Smart Placement is enabled. Its latency benefit has not been remeasured.
- Live acceptance already passed Auth/App Check, circle creation/join, fresh location ingestion, duplicate retry, older-fix watermark preservation, parent tracking rejection and foreign-circle rejection.
- A shared pending network-I/O bug in Worker authentication was fixed: only completed results are cached across invocations. Keep that boundary intact.
- Temporary acceptance accounts/documents/App Check debug registration were removed. Do not rerun the previously approved global reset: that one-time reset is complete.

## Remaining work, in priority order

Password recovery update (13 October 2026): sign-in now offers a separate scrollable reset screen with email prefilling/validation, duplicate-request protection, accessible status announcements, recoverable errors and generic account-existence wording. It uses the existing Firebase Auth email reset API; no dependencies or paid backend services were added. Full Flutter suite: 163 passed; additional reset service regression: 1 passed. Actual email delivery and phone/TalkBack acceptance remain pending. ADB reported no attached devices.

### 1. Finish practical app gaps

- Accessible **Forgot password** flow is implemented on `taha/password-recovery`; verify actual email receipt/reset with an isolated test account before release.
- Nunito weights 400–900 are bundled; runtime Google Fonts fetching/dependency has been removed. The font license is included and accessible from Settings.
- Main, history and place-picker maps now use shared visible, linked OpenStreetMap attribution.
- Installed flutter_map 7.0.2 was inspected: its default network provider has decoded-image memory caching, but no persistent HTTP cache. All three maps now use the shared SQLite tile cache with HTTP expiry/validators, a seven-day fallback, coalesced requests and a 128 MiB payload bound. Local tests cover restart persistence, conditional requests, no-store handling, eviction and deletion fencing. On-device network/cache acceptance is still pending; do not claim universal policy compliance from unit tests alone.
- Android launcher display name is now **FamilyGuard**.
- Add accessible privacy-policy and deletion-request links once public pages exist.
- Continue device/TalkBack review across all flows. Place editing now passes a 320-pixel, 2× text and keyboard-inset regression; color choices have accessible labels/48-pixel targets, headings wrap, the radius announces meters, and directional buttons move the pin by 25 meters. History status/empty panels scroll when short of space.

### 2. Real-device acceptance — biggest engineering gap

No phone was attached to ADB at the latest check. Previously tested phone: Samsung SM_A065F, Android 16, serial `R8VY201YXJJ`, ARM64, 4 KB pages.

Use controlled parent and child accounts/devices and test:

- First install, sign-up/sign-in, circle creation/join and child disclosure before sharing.
- Fresh location on parent map, accuracy/age display, background/screen-off tracking, swipe-away and reboot.
- Airplane mode and reconnect, process restart, durable queue recovery and older-fix protection.
- Logout/account or circle changes with pending uploads; no old data appears in a replacement account.
- Permission withdrawal/restoration, approximate location, notification denial, battery saver and OEM restrictions.
- Real FCM receipt/opening, token refresh, resolved/delayed SOS and parent-only place notifications.
- Geofence arrival/departure on an actual moving route.
- Account deletion against the deployed Worker, Auth removal, remote cleanup and local erasure.

Do not silently trigger emergencies on real family accounts. Use isolated consenting test recipients.

### 3. Performance and free-plan capacity

- Remeasure create/join/location latency after Smart Placement; previous live wall times were about 4–9.5 seconds. Wall time is not CPU time.
- Profile the current app in profile/release mode: startup, scrolling/map frame time, CPU, memory growth and video lifecycle.
- Run an eight-hour stationary battery test and a one-hour moving route; record accuracy, capture-to-server delay and missed transitions.
- Previous short phone measurements on an older profile build: first frame about 2.99 seconds, settled CPU samples 0–1.6% of one core. These are not current-build or battery acceptance results.
- Measure actual Cloudflare CPU, errors, Firestore reads/writes and cleanup throughput under representative bounded load; define a supported launch size.
- Add useful privacy-safe operational monitoring and quota visibility. Worker observability is currently disabled in configuration.
- Workers Free documented limits: 100,000 requests/day, 10 ms CPU per invocation, 50 subrequests. Firebase Spark and cron cleanup also impose finite capacity. Reverify provider limits before capacity decisions.

### 4. Production identity, signing and signed-build verification

- Owner must choose the permanent Android application ID. Current development ID is `com.example.family_guard`; do not invent the permanent identity.
- Register that identity in Firebase and update Android/Dart configuration consistently, including the Worker App Check app-ID allowlist.
- Configure upload signing through ignored `android/key.properties`; it did not exist at the audit. Maintain an independent secure keystore backup.
- Configure production App Check / Play Integrity for the signed app and verify foreground/headless requests.
- Build and inspect a signed AAB; verify certificate, merged permissions, bundled assets and release native libraries.
- Test on a real 16 KB Android runtime. ARM64 ELF and APK ZIP alignment checks have passed, but the Samsung device has 4 KB pages.
- Release validation deliberately rejects the placeholder identity and missing signing; never bypass it with debug signing.

### 5. Play Console and publication

- Owner previously said no Play Console account existed; account completion has not been confirmed.
- Google Play registration currently requires a $25 one-time fee. Backend operation can stay on free plans, but Play registration is not free.
- New personal accounts require at least 12 continuously opted-in closed testers for 14 days before applying for production access. A public launch next week is not feasible when starting that requirement now.
- Publish accurate privacy and account-deletion request pages; provide a support contact.
- Complete Data safety, target audience/content rating, background-location disclosures/review, foreground-service declarations and reviewer access instructions as applicable.
- Prepare screenshots, feature graphic, final listing copy and test distribution.
- Use Play pre-launch checks and closed-test feedback before production submission.

### 6. Documentation and integration

- Keep this file current. Redundant feature/release reports and obsolete paid-backend deployment instructions have been removed. Original owner-provided Firebase/design notes remain historical references, not the active deployment guide.
- After final feature fixes, require green CI and integrate the verified stacked head into main.
- Keep unit/widget, real SQLite, backend domain, Firestore rules, REST adapter and Worker runtime tests in CI.

## Local tooling — no global installs

- Flutter: `D:/ProgramData/SDKFlutter/flutter` (3.41.7; Dart 3.11.5).
- Dart executable: `D:/ProgramData/SDKFlutter/flutter/bin/cache/dart-sdk/bin/dart.exe`.
- Flutter CLI snapshot: `D:/ProgramData/SDKFlutter/flutter/bin/cache/flutter_tools.snapshot`.
- JDK: `D:/ProgramData/AndriodSDK/jbr` (spelling is intentional).
- Android SDK: `D:/AndroidSDK`; ADB: `D:/AndroidSDK/platform-tools/adb.exe`.
- Node: `C:/Program Files/nodejs/node.exe`.
- Python: project `.venv/Scripts/python.exe`; set pip cache to `.cache/pip`.
- Set `PUB_CACHE` to repository `.pub-cache`, `GRADLE_USER_HOME` to `.cache/gradle` and npm cache to `.cache/npm`.
- Wrangler: `workers/node_modules/wrangler/bin/wrangler.js`. Set `XDG_CONFIG_HOME` to `.cache/cloudflare` and `WRANGLER_SEND_METRICS=false`.
- Existing Wrangler authorization is complete. Credentials live in ignored local cache; never print them.
- Direct Dart + Flutter snapshot invocation is more reliable than `flutter.bat` on this machine.
- Update **both** root `pubspec.lock` and `tool/sqlite_tests/pubspec.lock` when root dependencies change. CI enforces both.
- Windows host has limited memory; avoid running several native builds/emulators simultaneously. Native builds can take minutes with little output.

Example PowerShell verification:

```powershell
$env:PUB_CACHE = "$PWD/.pub-cache"
& 'D:/ProgramData/SDKFlutter/flutter/bin/cache/dart-sdk/bin/dart.exe' `
  'D:/ProgramData/SDKFlutter/flutter/bin/cache/flutter_tools.snapshot' analyze --no-pub
& 'D:/ProgramData/SDKFlutter/flutter/bin/cache/dart-sdk/bin/dart.exe' `
  'D:/ProgramData/SDKFlutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub
```

Run durable SQLite tests from `tool/sqlite_tests`. Backend and Worker commands are in root/Workers `package.json` and CI. Use emulator project `demo-family-guard` for local integration tests, not the live project.

## Existing artifacts and evidence

- Current local debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, rebuilt from app commit `e5b15c2`. Package inspection verified all six Nunito weights/license, FamilyGuard launcher label, no exact-alarm permissions, six ARM64 libraries with 16 KB ELF alignment, and APK ZIP alignment. This is a development/debug build; production identity/signing and real 16 KB runtime acceptance remain pending.
- Onboarding preview: `build/regression-validation/interactive-intro.png`.
- Bundled video: `assets/videos/family_intro.mp4` (six seconds, approximately 41 KB).
- Icon preview: `assets/branding/icon_preview.png`.
- Reproducible media generator: `scripts/generate_intro_assets.py` with project-local requirements.
- Older standalone regression reports were removed; current verification results and remaining acceptance limits are summarized here.
- Ignored device logs/screenshots may contain private family data; never commit them.

## Official references

- Play registration: https://support.google.com/googleplay/android-developer/answer/6112435
- New personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Workers limits: https://developers.cloudflare.com/workers/platform/limits/
- Firebase pricing/quotas: https://firebase.google.com/pricing
- OpenStreetMap attribution and tile policy: https://operations.osmfoundation.org/policies/tiles/
- Bundled Nunito source/license: https://github.com/google/fonts/tree/main/ofl/nunito . Weights 400–900 are static instances of the official variable font, generated with fontTools 4.60.1 in the project `.venv`; the complete OFL is included in assets and the in-app license registry.

## Offline maps/fonts and accessibility verification — 13 October 2026

Branch `taha/offline-map-polish` includes password recovery through its parent branch. Local validation: **172 Flutter tests, 9 real SQLite tests, and clean Flutter analysis**. A follow-up cache regression verifies that stalled connections time out, retry succeeds and late responses do not restore cleared tiles; scoped analysis also passed after that fix. Both dependency lockfiles are synchronized from the existing local package cache. No backend deployment, billing or paid service changes were made.

Android ARM64-targeted debug build succeeded. APK inspection verified bundled font weights/license, the launcher label, native library/ZIP alignment and absence of exact-alarm permissions. The debug artifact is approximately 125 MiB and still declares additional plugin ABIs; do not use its size as a release download estimate.

Map caching saves only requested public basemap images and HTTP validators, not family markers, routes or names. Stored tiles still reveal previously viewed areas; Settings offers **Clear map cache**. Account deletion clears this cache and decoded map images, with generation fencing so pending requests cannot repopulate cleared storage. SQLite secure deletion is enabled. Tile requests identify FamilyGuard, honour HTTP expiry/ETag/Last-Modified/no-store, use a seven-day fallback when expiry is unavailable, and do not add bulk downloads or offline-area features. Storage failure falls back to network rather than preventing the map from opening; real-device storage/network acceptance is still required.

Place editing adds labelled 48-pixel color choices, wrapping headings, a spoken radius value and 25-meter directional pin controls with an announced coordinate display. A regression covers 320-pixel width, 2× text, keyboard insets and actual pin movement. History loading/error/empty panels can scroll when space is short. These tests do not replace TalkBack or visual acceptance on a phone.

## Suggested first instruction in the next chat

"Read next_steps.md and inspect the current Git state. Password recovery, offline fonts, map attribution and local tile caching are implemented. Check current CI and continue release preparation on taha feature branches. Keep dependencies local and the backend free. Public policy/deletion pages, support contact, permanent application ID and signing need owner input. Proceed to controlled device acceptance and performance measurements when phones are connected. Never reset live data or send real emergency alerts during routine tests."

## Repository structure and maintenance notes

- `lib/core/`: shared models, services, providers, privacy and theme.
- `lib/features/`: auth, onboarding, map, history, places, alerts, SOS, settings and home.
- `functions/features/`: backend business logic reused by the Worker; keep this code even though paid Cloud Functions are not deployed.
- `workers/src/`: free backend transport, authentication and Firestore REST adapter.
- `test/`, `functions/test/`, `workers/test/`, `tool/sqlite_tests/`: regression coverage.
- `scripts/`: local verification, native alignment checks and asset generation.
- `.github/workflows/`: automated verification; the PR template is workflow metadata, not a separate reading guide.

Auth is the identity authority. Preferences cache display data only. Membership, roles, SOS and trusted ingestion remain server-owned. Preserve injectable services and clocks, account/circle fencing, original capture timestamps, idempotent retries and the shared foreground/headless upload policy.

Consent is scoped to the account, sign-in and circle. Parents avoid child location prompts. Children cannot hand off another member's location. Parent history is restricted to the recorded circle; never infer legacy point provenance from current membership. A dedicated parent handoff/leave-circle flow is still a product gap; existing surviving circles with no parent enter `requiresParent` recovery.

The Worker supports the current private subcollections and stores deletion cleanup stages. Extend deletion steps/tests whenever adding new private data. Minute recovery sweeps resume signed jobs; half-hour sweeps prune expired records in bounded batches. Empty sweeps still consume Firestore reads, and expired-history cleanup is bounded (previous configured maximum: 9,600 points/day). Measure actual capacity before launch.

For authorized deployments only, use the existing local Wrangler from `workers/` and Spark-compatible Firebase deployment from the root. Do not reprovision credentials:

```sh
# From workers/, with the local cache/auth configuration described above:
node node_modules/wrangler/bin/wrangler.js deploy --config wrangler.jsonc

# From the repository root:
node node_modules/firebase-tools/lib/bin/firebase.js deploy --project familyguard-v2-app --config firebase.spark.json --only firestore
```

Preserve disclosure, session boundaries and retry behavior when changing UI. Missing/stale positions and unknown battery/activity must remain honest; FCM service acceptance must never be described as device receipt.

Regenerate original introduction/icon assets using the project virtual environment:

```powershell
.venv/Scripts/python.exe -m pip install --cache-dir .cache/pip -r scripts/intro-assets-requirements.txt
.venv/Scripts/python.exe scripts/generate_intro_assets.py
```

The introduction is silent, 720 × 576 H.264 at 24 fps. Its poster supports reduced motion and video failure. Pause playback in the background and dispose the player when leaving onboarding. Demo interactions must never start real tracking or send alerts.

## Copy review and integrated refinements — 13 October 2026

Reviewed `D:/Flutter_Projects/copy/Family-Guard`, an older shared Git base with uncommitted UI refinements. Do not replace the current app/backend with that copy. Its cached identity tokens, client-side retention, estimated trip distances and debug release signing are superseded.

Integrated the useful ideas into the current code:

- History cards select a captured trip/stay, highlight selection, fit the map to its coordinates and offer Show all. Selection resets across account/circle/role/member/timeframe/loading changes; pagination and recorded-circle access remain intact. Overall route points are chronological.
- Short segments show < 1 min; a single point says Captured at rather than claiming an arrival. Distance still comes from coordinates.
- Place setup lets the user explicitly choose a family member with fresh valid coordinates and recenter on that last shared position. The source name and time are shown. Existing places keep their saved position until the user explicitly changes it. No new location permission or external search service is introduced.

Address search remains optional future work. The old public Nominatim calls need a deliberate compliant provider decision, shared throttling, caching, attribution, cancellation and protection against stale results. Old branding assets are optional alternatives; current onboarding is more robust. The old copy directory and Tracelet spike are unchanged. A service-account key exists at the copy directory root; handle that credential separately before deleting/archive-sharing the folder.

Validation: 28 focused history/place tests passed; added regressions cover route filtering/reset, honest short durations and member selection/recentering. Final UI card/Show all pagination checks and analysis are run before pushing. Device visual acceptance remains pending.
