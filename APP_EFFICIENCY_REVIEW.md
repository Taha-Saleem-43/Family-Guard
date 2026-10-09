# Family Guard: architecture and efficiency review

Reviewed 9 October 2026. This is a source-level assessment, not a measured device benchmark or a deployed Firebase audit. Runtime code has not been changed.

## Product goal

Family Guard is a consent-based family safety app. Parents monitor their circle; child devices share location, movement and battery status. Saved places should generate arrival/departure events, history should explain trips and stays, and SOS should promptly alert the circle.

Efficiency means accurate, fresh information and reliable emergency delivery per unit of battery, network traffic, database work and user effort. The best next investment is the location-to-cloud pipeline and trustworthy state reporting, before cosmetic changes.

## Current architecture

- Flutter UI with Riverpod state; Firebase Auth and Firestore storage.
- Onboarding authenticates, creates/joins a circle, requests permissions and opens the main shell.
- Main shell starts Tracelet for child accounts. Location and motion callbacks feed MemberStateNotifier, which also polls battery every 120 seconds.
- MemberStateNotifier uploads accepted changes to the user document and a history point. Circle members are watched through a users query.
- Tracking uses high accuracy and a 10-metre distance filter. Upload policy is activity/charging/battery changes, movement of at least 50 metres after 45 seconds, or a 180-second heartbeat evaluated when callbacks occur.
- Headless events only append local diagnostic logs; they do not execute the upload path.
- Saved places have CRUD and distance calculations. Alerts currently render SOS history. SOS delivery uses an in-app Firestore subscription.
- History fetches all points in the selected window, then builds a timeline and route in memory.

## Findings, ordered by impact

| Priority | Evidence | Consequence and action |
|---|---|---|
| P0 | firestore.rules permits any authenticated user to read all users and circles; owners can change their own role/circleId. Parent history reads lack a same-circle check. SOS/place events accept authenticated reads/writes without circle restrictions. | Location privacy and authorization boundaries are not enforced. Implement authoritative membership, field allowlists and circle-scoped access; prove isolation with emulator tests. README's claim of blocked client role escalation is incorrect. |
| P0 | AuthService.createCircle swallows persistence errors. joinCircleByCode invents a circle ID if no match exists, derives role on query failure and can return demo_user without authentication. | Setup can report success without valid membership. Reject invalid invites and unauthenticated joins; surface backend failures; make circle creation and membership changes atomic and server-validated. |
| P0 | lib/main.dart backgroundLocationHandler writes only a debug log. Cloud upload lives in a UI provider. | Native tracking can continue while remote family locations stop updating. Use the same durable ingestion/upload pipeline from foreground and supported headless execution. Verify reboot and process-death behavior on devices. |
| P0 | No FirebaseMessaging or local-notification implementation is present in lib, despite dependencies. SOS subscription and receiver UI are tied to app execution/map presentation. | No implemented push path wakes or notifies background receivers. Add backend SOS event fan-out, device-token lifecycle, notification handlers, acknowledgement and deduplication. Move emergency handling to the authenticated app shell. OS delivery limitations still apply. |
| P0 | Settings sign-out calls AuthService.signOut and resets app state; neither stops Tracelet. Session restoration trusts SharedPreferences without reconciling Firebase Auth. | Tracking and retained provider state can outlive the intended session. Create one session coordinator that stops tracking, cancels listeners/timers and clears session-scoped state on logout or membership loss. Firebase Auth is the identity authority. |
| P1 | FirestoreLocationService.updateUserLocation calls purgeExpiredDocuments after each accepted upload. Purge issues six queries, including global event queries, and builds one unbounded delete batch. | High recurring database work, broad client deletion authority and retention failures. Remove cleanup from uploads. Use timestamp-based TTL or bounded privileged scheduled cleanup; remove client cross-user deletion rights. |
| P1 | LocationHistoryPoint and upload payloads serialize expireAt as an ISO string. | These fields are not suitable as Firestore TTL timestamps. Migrate existing records and readers/queries together before enabling TTL. Do not expire the permanent user profile. TTL is asynchronous and billed, so filter expired records in reads where needed. |
| P1 | Upload throttle fields update only after awaited writes/cleanup; callers do not await uploads. Live and history writes are sequential. | Concurrent callbacks can pass the same throttle gate and duplicate work; failures can leave partial state. Serialize uploads, coalesce pending normal fixes, batch live/history writes, and advance acknowledged state only on success. Persist retryable work with stable event IDs. |
| P1 | MemberStateNotifier seeds Islamabad coordinates and 95% battery; battery changes can upload those before a GPS fix. Missing lastSeen is interpreted as now. | Simulated positions/status can look genuine. Represent unknown position, battery and freshness explicitly; require a validated fix before location publication. Keep demo fixtures in an explicit demo/test environment. |
| P1 | Circle merge preserves entries missing from the remote snapshot; its existing-member branch searches a list from which matching IDs were already removed. | Departed members persist and local-self preservation is ineffective. Replace roster from the authoritative snapshot and overlay only valid self telemetry. Clear all circle data on identity/circle changes. |
| P1 | isStale is calculated only when a Firestore snapshot arrives. | A silent device can remain visually online. Derive freshness from received fix time using a lightweight foreground clock; distinguish stale, offline and permission-limited states. |
| P1 | PlacesService only stores places; no runtime geofence registration, transition event producer or notification path is present. | Arrival/departure toggles do not implement alerts. Register supported native geofences, persist transition state, apply dwell/hysteresis and deduplicate events before backend fan-out. |
| P1 | SOSNotifier marks self active before dispatch succeeds; resolve clears local state without checking success. SOSState.copyWith cannot clear nullable fields because it uses ?? fallback. | UI can claim an emergency is sent or resolved when it is not. Model pending/sent/failed/acknowledged/resolved states; support explicit null clearing; use atomic event/status writes and restore active SOS after restart. Ensure vibration cutoff also works if audio startup fails. |
| P1 | History falls back to generated trips when the result is empty, fetches without limits, groups descending points, clamps short stays to five minutes and derives distance from duration. | History can be fictional, reversed and expensive. Preserve empty/error states; aggregate in chronological order, split at gaps/day boundaries, calculate distance from valid coordinates, paginate and simplify route geometry. |
| P1 | Settings renders all permissions as granted; returning sessions bypass the permission gate. Android activity recognition is declared but not requested by PermissionService. iOS Info.plist lacks location usage descriptions/background location mode. | Health information is unreliable and platform setup is incomplete. Query actual status on resume, gate features by capability, request necessary motion permission and complete/test iOS configuration separately. |
| P2 | Providers watch the whole AppState; active-tab changes can invalidate circle streams/history fetches. MapScreen watches all SOS state, including the one-second duration counter. MainShell replaces tab bodies. | Avoidable queries, rebuilds and map recreation. Select circleId/userId/role independently; isolate timer widgets; preserve expensive map state deliberately while suspending invisible work. Profile before expanding caching. |
| P2 | Every fix rewrites a SharedPreferences string list capped at 10,000 entries, including release/headless execution. | Increasing serialization and disk work, unnecessary retention of precise location logs and isolate races. Disable routine production fix logging; use a small bounded diagnostic buffer or rotating database/file sink with retention and explicit diagnostics controls. |
| P2 | pubspec includes overlapping/unused packages, including Google Maps alongside the actual flutter_map UI. Android release uses debug signing and example application ID. | Audit actual imports, remove unused dependencies, bundle fonts if offline startup requires them, and configure release identity/signing. Validate dependency overrides against the resolved runtime graph. |

## Target tracking pipeline

```text
Native location / motion / geofence event
  -> validate fix (age, accuracy, coordinate range, ordering)
  -> persist durable event with stable ID and capture time
  -> policy engine (motion, battery, emergency, freshness)
  -> serialized uploader with retries and coalescing
  -> atomic latest-location + selected history writes
  -> circle-scoped viewer subscriptions

SOS / geofence transition
  -> authoritative event
  -> backend push fan-out
  -> receiver notification + acknowledgement

Retention -> server TTL / bounded scheduled cleanup
```

Separate permanent profiles/membership from high-frequency telemetry. For example, use circles/{circleId}/members/{uid}, circles/{circleId}/locations/{uid}, user-owned history and circle-scoped events. A path alone is not authorization: membership and write fields must be enforced. Keep private invite records outside documents readable by every member; use secure expiring/revocable invites with rate-limited server redemption.

Keep Firebase as the backend for now. A backend rewrite would not fix the lifecycle and synchronization problems. Introduce repositories and injectable clock, location, battery and persistence interfaces so policies and failures can be tested independently of widgets/plugins.

## Adaptive policy to evaluate

These are starting hypotheses, not validated Tracelet settings or promises of OS scheduling frequency. Confirm APIs against the installed plugin before implementation.

| Mode | Capture and upload approach |
|---|---|
| Stationary | Motion/geofence monitoring; reduce GPS use; publish a configurable 5–10 minute freshness heartbeat where the OS permits. Do not append identical history points for every heartbeat. |
| Walking | Evaluate 25–50 metre capture distance and 30–60 second upload freshness; immediately publish meaningful transitions. |
| Driving | Evaluate 50–100 metre capture distance and 15–30 second upload freshness; retain enough route detail for useful history. |
| Low battery | Widen normal thresholds and reduce optional work; show reduced freshness explicitly. Preserve emergency dispatch priority. |
| SOS | Persist/send immediately using the best available fix with age/accuracy metadata; request a fresh fix in parallel. Apply a temporary tracking boost with an explicit timeout and restore the previous policy on resolution. |
| Temporary live viewing | Offer a bounded, authorized freshness boost while a parent actively follows a member, then return to normal mode. |

The existing 180-second heartbeat is a condition on incoming callbacks, not an independently scheduled heartbeat. Do not display a three-minute freshness guarantee until this is measured end to end.

## Database work model

Under an idealized continuous 180-second upload cadence, one tracked device creates 480 uploads/day: 960 document writes plus 2,880 cleanup query executions before returned documents, listener reads or event changes. At 45-second moving cadence, that becomes 1,920 uploads, 3,840 writes and 11,520 cleanup query executions/day. Actual activity/battery triggers and races can increase work; absent fixes can reduce it. Query executions are not equivalent to billed document reads.

Removing purge from the hot path eliminates all six recurring cleanup queries per accepted upload. Separating status heartbeats from history append prevents stationary devices from accumulating redundant route points. Measure listener fan-out and viewer session length before choosing more complex transport or batching.

## Implementation order and completion criteria

1. **Trust and isolation:** fix rules and membership/invite flows, reject simulated success, reconcile authentication, stop/clear session work on logout. Complete when emulator tests deny cross-circle reads, role escalation, forged invites and arbitrary event changes.
2. **Durable tracking and efficient storage:** introduce shared background ingestion, validated fixes, stable IDs, serialized retry queue, atomic writes and server retention. Complete when reboot/process-death/offline recovery tests demonstrate fresh uploads without duplicates or false positions; upload path performs no cleanup queries.
3. **Complete safety features:** backend push delivery, shell-level receiver UI, SOS state recovery and native geofence transitions. Complete when two-device tests cover foreground, background, reconnect, dismissal versus resolution and duplicate messages.
4. **Battery and UI tuning:** measure baseline, tune adaptive policies, narrow provider dependencies, paginate history, simplify geometry and remove release diagnostic churn. Complete when device benchmarks show improved battery/network use while meeting agreed freshness and rendering targets.
5. **Release readiness:** complete platform setup, production signing, real capability dashboards, accurate product documentation and CI. Complete when supported-device regression tests and release builds pass.

## Measurement and meaningful tests

- Establish a repeatable 24-hour stationary/walking/driving scenario on a low-end Android, Samsung device and supported iPhone; compare against an idle control. Record incremental battery percentage points, GPS-active time, wakeups, bytes, uploads, reads and writes.
- Candidate targets: at least 50% fewer stationary history writes; zero cleanup queries on upload; at least 30% lower incremental battery use against baseline; p95 moving freshness under 60 seconds on healthy connectivity. Adjust targets after baseline; these are not measured results.
- SOS target: p95 server acceptance under two seconds on healthy connectivity. Measure receiver delivery and acknowledgement separately; network/OS restrictions prevent unconditional delivery guarantees.
- Profile map panning and marker updates in profile mode on physical devices; target frame budgets appropriate to refresh rate (about 16.7 ms at 60 Hz), bounded history memory and no recurring map rebuild driven by an SOS timer.
- Add injected-clock tests for exact distance/time/battery thresholds, activity jitter, concurrent callbacks, retry ordering, UID changes and failures between writes.
- Add emulator tests for actual writes, indexes, retention migration and permissions. Existing no-Firebase service tests exercise local state, not successful backend synchronization; one history test explicitly expects mock results.
- Test no-fix startup, clock skew, out-of-order fixes, airplane mode, permissions revoked in Settings, logout during an in-flight upload, account switching, member removal, expired invite and denied push permission.
- Test history with no data, gaps, midnight/timezone boundaries, stationary drift and long ranges. Test SOS dispatch failure, retry, restart restoration and nullable-state reset.

## Verification limits and references

Source inspection covered the runtime feature structure, core services/providers/models, platform declarations and representative tests. No live Firebase configuration or device behavior was inspected. No battery, latency or cloud-cost improvement is claimed as measured.

`flutter analyze` was attempted, but produced no output or result before being interrupted. This checkout has no `.dart_tool/package_config.json`; analysis and tests remain unverified. Do not interpret this review as a passing build or test report.

- [Firestore TTL](https://firebase.google.com/docs/firestore/ttl): timestamp fields, asynchronous expiry and billing considerations.
- [FCM Flutter receiving messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages): background handlers and force-stop/platform limitations.
- [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices): scope rebuilds and keep build work small.
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations): repository boundaries and testable application logic.
