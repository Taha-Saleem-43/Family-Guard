# FamilyGuard — handoff and next steps

Updated: 11 October 2026. Read this first when continuing in a new chat.

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
- Current branch: `taha/map-actions-cleanup`.
- Latest app commit: `1ccc451` — simplify map credits and Google Maps directions action.
- Remote main observed locally: `ebc00d4` — UI accessibility refinements.
- Current branch contains the newer Workers backend, onboarding and map work. Integrate the final verified head once; do not independently merge every stacked predecessor branch.
- Latest CI for `1ccc451`: **Android, Flutter and Firebase/backend jobs all passed**.
- CI evidence: https://github.com/Taha-Saleem-43/Family-Guard/actions/runs/38085743389
- This handoff file is documentation added after that tested app commit.

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

### 1. Finish practical app gaps

- Add an accessible **Forgot password** flow; no password-reset UI/service was found in the audit.
- Bundle the existing Nunito font assets or choose an offline system-font strategy. Current theme uses Google Fonts runtime fetching.
- Apply compact visible OpenStreetMap attribution to history and place-picker maps as well as the main map.
- Verify the actual tile caching behavior against the OSM usage policy. No explicit persistent tile-cache configuration was found in the app map widgets; do not claim caching compliance without checking the installed provider.
- Change Android launcher display name from `family_guard` to the chosen user-facing brand.
- Add accessible privacy-policy and deletion-request links once public pages exist.
- Review small screens, large text, keyboard handling, TalkBack, contrast, and tap targets across all flows, preserving consent and error/retry behavior.

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

- Update `RELEASE_STATUS.md` and `docs/RELEASE_RUNBOOK.md`: sections still describe undeployed paid Firebase Functions/TTL and pre-device-test status. Use this handoff and `workers/README.md` for the newer free-backend state.
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

- Last local debug APK: `build/app/outputs/flutter-apk/app-debug.apk`. It was built before the latest map cleanup; use current CI artifact or rebuild for current UI device testing.
- Onboarding preview: `build/regression-validation/interactive-intro.png`.
- Bundled video: `assets/videos/family_intro.mp4` (six seconds, approximately 41 KB).
- Icon preview: `assets/branding/icon_preview.png`.
- Reproducible media generator: `scripts/generate_intro_assets.py` with project-local requirements.
- Previous regression evidence: `build/regression-validation/REPORT.md` and `WORKERS_REPORT.md`; older sections are historical, not current status.
- Ignored device logs/screenshots may contain private family data; never commit them.

## Official references

- Play registration: https://support.google.com/googleplay/android-developer/answer/6112435
- New personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Workers limits: https://developers.cloudflare.com/workers/platform/limits/
- Firebase pricing/quotas: https://firebase.google.com/pricing
- OpenStreetMap attribution and tile policy: https://operations.osmfoundation.org/policies/tiles/

## Suggested first instruction in the next chat

"Read next_steps.md and inspect the current Git state. Continue the remaining engineering work on taha feature branches, starting with password recovery, offline fonts, map attribution/cache review and release-document corrections. Keep dependencies local, preserve the free backend, test and push completed work. Do not reset live data or send real emergency alerts. Then proceed to controlled device acceptance and performance measurements when phones are connected."
