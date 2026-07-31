# Part A — Figma Design Prompt

Copy everything in this section directly into Figma AI / Figma First Draft (or hand to a designer) as one brief.

---

## Design Brief: Family Safety App (Life360-style, parent/child model)

**App purpose:** A family-safety app with four core features: real-time location sharing, place alerts (geofencing), location history, and SOS/emergency alerts. Two roles: **Parent** (sees all children's locations) and **Child** (sees only their own location, place alerts, and an always-visible "you're being monitored" indicator).

**Visual direction — reference apps to draw from:**
- **Life360**: warm, reassuring color palette (soft blues/greens, not clinical), rounded map pins with member avatars, bottom-sheet member cards over a full-screen map, circular "Places" markers with radius rings shown translucent on the map.
- **Google Family Link**: clean card-based settings screens, clear iconography for permissions/consent screens, friendly illustration style for onboarding (avoid anything that feels like a legal document).
- **Find My (Apple)**: minimal bottom-sheet member list with small live-updating dots, smooth map-first layout, SOS treated as a distinct red/urgent visual language separate from the rest of the calm palette.
- **Tone overall:** trustworthy, warm, non-clinical, family-oriented — not "security dashboard," not "surveillance tool." Typography friendly/rounded (e.g. similar weight to SF Pro Rounded / Inter with rounded numerals). Primary palette: calming blues/teals for normal state, distinct urgent red reserved ONLY for SOS states so it stands out.

**Design system tokens to define first (before screens):**
- Color: primary, secondary, background, surface, success (place-arrival), warning, danger/SOS-red, text-primary, text-secondary, map-pin-parent, map-pin-child (each family member gets a distinct pin color/avatar ring).
- Typography scale: H1/H2/H3, body, caption, button label.
- Spacing scale (4/8/12/16/24/32).
- Corner radius scale (cards: 16-20px rounded, buttons: full-pill or 12px, map pins: circular).
- Elevation/shadow tokens for bottom sheets and floating cards over the map.

---

## Full Screen List to Design

### 1. Onboarding & Auth flow
1. Splash/logo screen
2. Welcome carousel (3 slides: "See your family's location," "Get alerts when they arrive," "SOS for emergencies")
3. Sign up screen (email/phone)
4. Log in screen
5. Create Circle vs Join Circle (choice screen)
6. Create Circle — name your Circle
7. Join Circle — enter invite code (two variants to design: parent-invite code entry, child-invite code entry — visually distinguish which role is being joined)
8. Invite Circle members screen (share parent-invite / child-invite links separately, clearly labeled)

### 2. Consent & Permission flow (design BOTH a parent-facing and child-facing version of each)
9. Disclosure screen — parent version ("You'll be able to see [child]'s location...")
10. Disclosure screen — child version ("Your parent will see your location, including when the app is closed. You'll always see a notification when this is active.") — must feel honest and clear, not buried in fine print
11. Location permission request pre-prompt (explaining why, before the system dialog)
12. Background location permission pre-prompt (second, separate ask)
13. Notification permission pre-prompt
14. Battery optimization exemption pre-prompt ("Keep tracking reliable")
15. OEM auto-start settings redirect screen (Samsung/Xiaomi/etc. — generic "let's fix one more setting" screen)
16. Permission success/all-set confirmation screen

### 3. Home / Map (core screen, both roles — design two variants)
17. **Parent home**: full-screen map, all children's live pins with avatar rings, bottom sheet listing each child (name, avatar, last-seen time, battery %, "at Home" / moving status), tap a child to focus map on them
18. **Child home**: full-screen map showing only their own pin + saved Places, persistent banner/chip at top: "Sharing location with [Parent name]" with a small "i" info tap target, no other family pins visible
19. Member detail bottom sheet (expanded) — avatar, name, address/place they're at, last updated, speed if moving, battery level, quick actions (Call, Directions, View History)

### 4. Location History (Timeline)
20. History screen — date/range selector (Today / 7 days / 30 days tabs)
21. History map view — polyline route overlay for selected day
22. History list view — scrollable stops list with timestamps, alternate/toggle with map view
23. Empty state (no history yet)

### 5. Place Alerts
24. Places list screen — saved places with icon, name, address, small radius indicator
25. Add/Edit Place screen — map with draggable pin + radius slider, name field, icon picker (Home/School/Work/Custom)
26. Place alert settings — toggle per member "notify me when they arrive/leave," per place
27. Place event notification (design the actual push notification + in-app toast: "Emma arrived at School — 3:15 PM")
28. Activity/alerts feed screen — chronological log of all arrive/leave events across the Circle (parent view only)

### 6. SOS / Emergency
29. SOS button — persistent, prominent, accessible from the home screen (design as a floating action button or fixed bottom element, visually distinct red, always reachable within 1 tap from map)
30. SOS press — 3-second cancel countdown overlay (large countdown number, clear "Cancel" tap target)
31. SOS active state — full-screen urgent state showing the alert is live, location being sent, who's been notified
32. SOS received (other members' view) — full-screen urgent alert with sender's name/photo, live location, "Call," "Get Directions," "Acknowledge" buttons
33. SOS resolved/acknowledged confirmation screen
34. SOS history log screen (past SOS events, status, who responded)

### 7. Settings & Circle management
35. Circle members list (parent view: manage roles, remove member, resend invites)
36. Circle members list (child view: read-only, just see who's in the Circle)
37. Individual profile/account settings
38. Notification preferences screen
39. Privacy/data settings screen (view what's collected, data retention info)
40. Permission status dashboard ("Location: Always Allowed ✓, Battery: Unrestricted ✓" — surfaces exactly what Section 8 of the build plan needs users to be able to check)

### 8. Error/edge states (design these explicitly, don't skip)
41. No internet connection banner/state
42. Location permission revoked warning banner
43. "Last seen 2 hours ago" stale-location state on a member pin
44. Force-stop warning explainer (if the app detects it was reopened after being stopped — explain tracking paused)

---

## Component Library to Build in Figma (before screens, as reusable components)

- Map pin with avatar (variants: parent, child, selected/unselected, stale/live)
- Place marker + radius ring (variants: home/school/work/custom icon)
- Bottom sheet (collapsed/expanded states)
- Member list row
- Primary/secondary/danger buttons
- Permission pre-prompt card template
- Notification/toast templates (arrival, SOS, low-battery)
- SOS countdown overlay
- Status chip ("Sharing location," "Monitoring active," "Offline")
- Tab bar / bottom navigation (Map, History, Places, Alerts, Settings)

## Deliverable format requested from Figma
- One Figma file, pages organized as: `00 Design System`, `01 Onboarding`, `02 Permissions`, `03 Home-Parent`, `04 Home-Child`, `05 History`, `06 Places`, `07 SOS`, `08 Settings`, `09 Error States`.
- Frames sized for a standard Android device (390×844 baseline, Android large-screen variant optional).
- Prototype links connecting the flows: onboarding → permissions → home, and SOS press → countdown → active → resolved.

---

# Part B — Structured Execution Plan (Tracelet confirmed working)

Since Phase 2b's Tracelet validation is done and passed on your end, this plan proceeds directly with **Tracelet as the confirmed background-location engine** — no fallback branch needed. Every step below is small, has a single objective, and has explicit test cases that must pass before moving to the next step. Do not let an agent skip a test case or bundle two steps together "for efficiency" — the whole point of this structure is catching failures early and small.

---

## Step 0 — Environment & repo setup
**Do:** Create Flutter project (`minSdkVersion 26`, `targetSdkVersion 34`), set up git repo, add `tracelet`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `google_maps_flutter`, `sqflite`, `flutter_riverpod`, `permission_handler`, `flutter_local_notifications`, `dio`.
**Test cases:**
- [ ] `flutter run` launches a blank app on a physical Android 14 device with no errors.
- [ ] `flutter build apk --release` succeeds (confirms no early Gradle/manifest conflicts before real work begins).

## Step 1 — Firebase project & security rules skeleton
**Do:** Create Firebase project, enable Auth (email), Firestore, Cloud Messaging, Cloud Functions. Write the Firestore data model exactly per the roles/collections defined earlier (`users`, `circles`, `places`, `locations`, `locationHistory`, `placeEvents`, `sosEvents`), with role field on `users`.
**Test cases:**
- [ ] A manual document write/read via Firebase console succeeds against each collection.
- [ ] Default Firestore rules are locked down (deny-all) before any client code is written — confirm via Firebase console rules simulator that an unauthenticated read is denied.

## Step 2 — Auth + Circle creation/join (parent & child invite codes)
**Do:** Build `AuthService`: sign up/sign in, create Circle (assigns creator role `parent`), generate two distinct invite codes (parent-invite, child-invite), join-by-code flow that sets `role` from the code type — never let the user pick their own role.
**Test cases:**
- [ ] Account A signs up, creates a Circle, is stored with `role: parent`.
- [ ] Account B joins via the child-invite code, is stored with `role: child`, and cannot self-modify that role from any client code path.
- [ ] Account B attempting to join via a malformed/expired code gets a clear error, not a silent failure.
- [ ] Firestore rules: manually attempt (via console or a test script) to write `role: parent` from an authenticated child account — must be denied.

## Step 3 — Role-aware Firestore security rules (write these now, not later)
**Do:** Implement the asymmetric rules: `locations/{userId}` and `locationHistory/{userId}/**` readable by `request.auth.uid == userId` OR requester role == parent; writable only by `request.auth.uid == userId`. Same pattern for `placeEvents`. `sosEvents` readable/writable by any circle member.
**Test cases:**
- [ ] Using the Firebase Rules Playground/simulator: a child-role read of another child's or the parent's `locations` doc is denied.
- [ ] A parent-role read of any child's `locations` doc is allowed.
- [ ] A child attempting to write to another user's `locations` doc is denied (including attempting to write the parent's).
- [ ] An SOS write/read from either role succeeds.

## Step 4 — Onboarding & consent screens (build from Figma, wire no location code yet)
**Do:** Build all screens from Figma pages `01 Onboarding` and `02 Permissions`, both role variants. Wire navigation only — no real permission requests yet, just UI + routing logic based on which invite type was used.
**Test cases:**
- [ ] Parent flow and child flow each render their correct disclosure copy (visually diff them — they must not be identical).
- [ ] Child disclosure screen cannot be skipped via back button, swipe, or any navigation shortcut — confirm by attempting each.
- [ ] All screens match Figma spacing/typography within reasonable tolerance (manual visual QA against the file).

## Step 5 — Real permission requests (wire actual Android permission dialogs)
**Do:** Implement the sequential requests: fine location → background location (separate ask) → notifications → battery optimization exemption → OEM redirect.
**Test cases:**
- [ ] On a fresh install, requesting background location before foreground location is granted is never attempted (verify by reading the code path, not just observing — a race condition here fails silently).
- [ ] Denying background location routes the user to a "foreground-only" degraded state with a visible banner, not a crash or dead-end screen.
- [ ] Full-grant path: all four permissions show as granted in Android Settings after completing onboarding on a real device.
- [ ] Test on both a Pixel and a Samsung device — OEM redirect screen only appears on the Samsung one.

## Step 6 — Tracelet integration: minimal tracking, no UI yet
**Do:** Configure Tracelet exactly as validated in your Phase 2b spike (same accuracy/interval/notification settings that passed). Wire the location-update callback to write directly to a local debug log only — not Firestore yet. This isolates "does tracking work in the real app" from "does the app correctly sync to the backend," so a failure here can't be confused with a Firestore bug later.
**Test cases:**
- [ ] Repeat your Phase 2b spike's exact 4 tests (baseline, Doze, reboot, 8-hour idle) but inside the real app shell this time, not the throwaway test app — confirm the plugin behaves identically once real app code/dependencies are added around it (a common failure mode: a plugin works in isolation but conflicts with another dependency in the full app).
- [ ] Child device's persistent notification shows the correct monitoring-disclosure text (not generic copy) throughout all 4 tests.

## Step 7 — Firestore sync for live location (Feature: Real-Time Location Sharing)
**Do:** Wire the Tracelet callback to write to `locations/{userId}` (overwrite) and queue to local SQLite, with a sync worker flushing to `locationHistory` on connectivity.
**Test cases:**
- [ ] Parent app's map (built from Figma `03 Home-Parent`) shows the child's live pin updating within the configured interval, phone backgrounded, screen off, 15+ minutes.
- [ ] Child app's map shows only its own pin, never a sibling's or parent's — confirm by attempting to manually query another user's doc from the child app's debug console and seeing it denied.
- [ ] Kill connectivity (airplane mode) for 10 minutes, then restore — queued points sync to `locationHistory` without gaps or duplicates.
- [ ] Reboot the child's phone without reopening the app — tracking and the disclosure notification both resume automatically, and location again begins flowing to the parent's map.

## Step 8 — Location History screen (Feature: Location History)
**Do:** Build `05 History` screens, query `locationHistory/{userId}/points` with date-range filters, render polyline + list view.
**Test cases:**
- [ ] A day with real recorded movement (walk around the block with the test device) renders a polyline matching the actual route.
- [ ] Empty state renders correctly for a day with no data.
- [ ] Switching between Today/7-day/30-day tabs loads correctly without stale data bleeding across tabs.
- [ ] Child account can view its own history; attempting to view a sibling's history (if UI somehow allowed it) is denied server-side.

## Step 9 — Places & Geofencing (Feature: Place Alerts)
**Do:** Build `06 Places` screens, register geofences via Tracelet's geofence API, write `placeEvents` on enter/exit, Cloud Function triggers an FCM push to parents (and to the child themself if you choose to notify them of their own arrivals).
**Test cases:**
- [ ] Adding a Place from the parent app correctly registers a geofence on the child's device (confirm via device logs, not just "no error shown").
- [ ] Physically entering/exiting the geofence radius (or using `adb` mock location to simulate it) produces a `placeEvents` write and a push notification to the parent within seconds.
- [ ] Reboot the child's device — confirm geofences are still registered afterward (query Tracelet's active geofence list post-reboot) without reopening the app.
- [ ] Deleting a Place from the parent app removes the corresponding geofence registration on the child's device on next sync.

## Step 10 — SOS / Emergency Alerts (Feature: SOS)
**Do:** Build `07 SOS` screens, wire the countdown → active state → Firestore write → Cloud Function → high-priority FCM push to all other Circle members → acknowledge/resolve flow.
**Test cases:**
- [ ] Pressing SOS on the child device and immediately cancelling within the 3-second countdown does NOT create an `sosEvents` doc or send any notification.
- [ ] Letting the countdown complete creates the event and delivers a high-priority push to the parent device within a few seconds, even with the parent's app fully backgrounded.
- [ ] SOS location capture bypasses normal throttling and captures a fresh high-accuracy fix, not a stale cached one (verify timestamp is current, not the last routine update).
- [ ] Acknowledging from the parent device updates `status` and is visible on the child's device.
- [ ] Test with the sending device's connectivity poor/intermittent — confirm retry logic actually resends until delivered, don't just assume the first attempt succeeds.

## Step 11 — Error handling & offline resilience pass
**Do:** Add try/catch + SQLite retry queue around every Firestore write, permission-revocation listener with persistent banner, battery-level reporting on each location update, Firebase Crashlytics integration.
**Test cases:**
- [ ] Revoke location permission manually mid-session (Settings) — app shows the warning banner within one app-resume, does not crash.
- [ ] Force a Firestore write failure (airplane mode mid-write) — confirm the point is queued locally and not silently dropped, verify it appears in Firestore once reconnected.
- [ ] Crashlytics dashboard shows a test crash correctly after a deliberately triggered test exception.

## Step 12 — Multi-OEM device matrix testing (final gate before considering this done)
**Do:** Run the full test suite from Steps 6, 7, 9, and 10 again, end-to-end, on at least: one Pixel/stock Android device, one Samsung device, one Xiaomi device if available.
**Test cases (per device):**
- [ ] 30+ minutes screen-off idle: location still updates.
- [ ] Doze mode forced via adb: location still updates or resumes correctly on Doze exit.
- [ ] App swiped from recents: tracking continues (foreground service survives).
- [ ] Device reboot without reopening app: tracking, geofences, and disclosure notification all resume automatically.
- [ ] Low battery mode enabled: document what degrades (expected — note it, don't try to defeat OS-level battery saver behavior).
- [ ] Explicit force-stop from Settings: confirm tracking stops (expected/acceptable) and that reopening the app cleanly resumes it — this is the one scenario allowed to fail per the plan's non-goals, just confirm it fails gracefully rather than corrupting state.

## Step 13 — Settings, Circle management, and remaining Figma screens
**Do:** Build `08 Settings` screens — permission status dashboard, Circle member management, privacy/data settings, notification preferences.
**Test cases:**
- [ ] Permission status dashboard accurately reflects real device permission state (cross-check against Android Settings directly).
- [ ] Parent can remove a Circle member; that member's app correctly loses access to shared data (Circle-scoped Firestore rules re-verified after removal).

## Step 14 — Final polish, error states, and pre-release checklist
**Do:** Build `09 Error States` screens, run a full regression of Steps 5–12 one more time on a clean install, prepare Play Console listing with background-location disclosure/data-safety form filled out accurately.
**Test cases:**
- [ ] Fresh install → full onboarding → all four features working end-to-end on two physical devices (one parent, one child) with no manual debug intervention.
- [ ] Play Console Data Safety form matches exactly what the app actually collects (this is checked in review — mismatches cause rejection).

---

## How to hand this to an agent

Give the agent **Part A first**, have it produce the Figma file, review it yourself against the screen list before moving on. Then give it **Part B**, one step at a time — do not let it proceed to Step N+1 until you've confirmed the Step N test cases pass. If any test case fails, that step is not done; fix it before moving forward, since later steps assume earlier ones are solid (Step 7 assumes Step 6's raw tracking already survived Doze/reboot, for example — debugging both at once wastes time telling them apart).
