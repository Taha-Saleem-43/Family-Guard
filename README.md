# Family Guard 🛡️

A modern, real-time family safety and location-sharing application built with **Flutter**, **Firebase**, and **Riverpod**, styled with a Material 3 design system.

Features real-time location tracking, a continuous background location engine, geofence place alerts, movement history timeline, role-based parent/child experiences, an instant SOS emergency panic system, a production-grade runtime permission gate with OEM-aware background setup, and a comprehensive settings dashboard.

---

## ✨ Implemented Features & Modules

### 🔐 1. Authentication & Family Circle Management
- **Firebase Auth Service**: Email & Password sign up, sign in, sign out, and session state streams (`AuthService`).
- **Family Circle Creation & Joining**: Parents can create a new family circle (generates a unique 6-character invite code) or members can join an existing circle via invite code.
- **Role-Based Experiences**: Support for **Parent** (full circle monitoring, place creation, history inspection) and **Child** (location broadcasting, quick status updates, panic SOS trigger) roles.
- **Server-Side Role Assignment**: Role is always derived from the invite code type (`PARENT-XXXX` / `FAMILY-XXXX`) — never user-selected. Firestore security rules block any client-side role escalation.

### 🗺️ 2. Interactive Map & Live Tracking (`MapScreen`)
- **Member Location Markers**: Map interface displaying family members with custom color-coded avatar markers.
- **Live Movement & Battery Badges**: Real-time status indicators for movement state (Stationary 🛑, Walking 🚶, Driving 🚗), battery levels (with low battery warnings 🔋), and connection status.
- **Map Controls**: Quick re-center, zoom, map layer toggle, and custom grid painter fallback mode.
- **Member Status Carousel**: Interactive bottom sheet displaying speed, address, battery %, timestamp, and quick call/directions actions.

### 📍 3. Places & Geofencing (`PlacesScreen`)
- **Geofence Places**: Support for Home, School, Work, and Custom places with configurable boundary radii (100m – 1000m).
- **Arrival / Departure Alerts**: Per-place toggling for entry/exit notifications.
- **Add Place Dialog**: Form to define new safe places with custom categories and location coordinates.

### 📜 4. Location History & Timeline (`HistoryScreen`)
- **Chronological Breadcrumb Trail**: Timeline log of member location history throughout the day.
- **Stop & Movement Details**: Displays arrival/departure timestamps, duration spent at locations, and movement speeds.
- **History Date Filter**: Navigation control to inspect location history across different dates.

### 🔔 5. Safety Alerts Feed (`AlertsScreen`)
- **Categorized Feed**: Filterable feed tabs (All, Places, SOS Emergencies, Battery warnings).
- **Read / Unread Tracking**: Status cards showing detailed alert timestamps, member details, and locations.

### 🚨 6. Emergency SOS Panic System (`SOSOverlay` & `SOSReceiverDialog`)
- **Full-Screen Emergency Overlay**: High-visibility red panic screen with a 3-second animated countdown to prevent accidental triggers.
- **Max-Volume Audio Siren & Haptics**: Overrides device volume to 100%, plays continuous high-priority emergency siren loop, and triggers heavy haptic vibration pattern on receiver devices.
- **Real-Time Circle Emergency Sync**: Dispatches instant emergency notifications with live GPS coordinates, reverse-geocoded address, and active duration ticker (`Active Duration • MM:SS`) across all circle members.
- **Streamlined Emergency Action Dialog (`SOSReceiverDialog`)**: High-urgency modal popup featuring 1-tap turn-by-turn navigation ("Get Directions") and full-width instant "Dismiss Alarm".
- **Persistent Floating SOS Trigger**: Global SOS trigger button accessible on top of main app shell screens (`MainShellScreen`).

### 🔑 7. Runtime Permission Gate & OEM Setup (`PermissionGateScreen`)
Inserted at the end of onboarding (after circle creation or join), before the user enters the main app.
- **Strict Sequential Permission Requests**: Permissions requested in strict order: foreground location → background location → notifications → battery optimization (`PermissionService`).
- **Pre-Prompt Cards**: Plain-language explanation card (icon + title + body) before system permission dialogs appear.
- **Degraded Modes**: Yellow warning banner for denied background location, red blocking banner with Settings deep-link for denied foreground location.
- **OEM Auto-Start Redirect**: Detects manufacturer via `device_info_plus` and shows custom auto-start instructions for Samsung, Xiaomi, OPPO, Huawei, Vivo, Realme, and OnePlus devices.
- **Permission Summary Dashboard**: Final summary screen displaying Granted / Limited / Skipped states for all permissions.

### 📡 8. Background Location Tracking Engine (`LocationService` & `Tracelet`)
- **Tracelet Plugin Integration**: Continuous background location tracking with high accuracy, 0m distance filter, persistent tracking across app termination (`stopOnTerminate: false`), and boot startup (`startOnBoot: true`).
- **Android Foreground Service**: Sticky system notification informing the user that location sharing is active.
- **Headless Task Handler (`@pragma('vm:entry-point') backgroundLocationHandler`)**: Background isolate callback that logs location fixes even when UI is closed or device reboots.
- **SharedPreferences Debug Logger**: Local timestamped log storage (`readDebugLog`, `appendDebugLog`, `clearDebugLog`) for diagnostic location inspection.
- **Health Check Monitoring**: Access to background service health metrics via `tl.Tracelet.getHealth()`.

### ⚙️ 9. Settings & Circle Management (`SettingsScreen`)
- **Circle Profile & Member Roster**: Displays circle name, active role, and a list of circle members with avatars and role badges.
- **Invite Code Sharing**: Displays child invite code with 1-tap clipboard copying for parent accounts.
- **Role Preview Toggle**: Segmented control allowing instant switching between Parent and Child view modes for UI testing.
- **Permission Status Dashboard**: Real-time monitoring card for Location, Background Tracking, Battery Optimization, and Notification statuses.
- **Sign Out & Reset**: Option to reset onboarding state and return to circle setup.

### 🎨 10. Modern Material 3 Design System & Theme
- **Design Tokens**: Standardized color palette in `AppColors` (`#EFF6FF` soft blue, `#3B82F6` primary blue, `#EF4444` SOS red, `#10B981` online green).
- **Typography**: Clean typography using Google Fonts **Nunito**.
- **Main Shell Screen (`MainShellScreen`)**: Fluid bottom navigation bar, top header avatar row, active circle badge, quick role toggle, and persistent floating SOS trigger button.

### 🗄️ 11. Firebase & Security Infrastructure
- **Firestore Security Rules (`firestore.rules`)**: Production-ready security rules covering user profiles, family circles, live locations, location history logs, places, place events, and SOS panic events.
- **FlutterFire Configuration (`lib/firebase_options.dart`)**: Auto-generated Firebase options for cross-platform integration.
- **Firebase Setup Guide (`How to setup Firebase.md`)**: Comprehensive guide for Firebase setup.

### 🧠 12. App State Management (`app_state_provider.dart`)
- **Riverpod Architecture**: Centralized `AppStateNotifier` managing app stage (`AppStage.onboarding` vs `AppStage.mainApp`), active user role (`UserRole.parent` vs `UserRole.child`), and active circle state.

---

## 📁 Project Architecture & Structure

```
lib/
├── core/
│   ├── models/            # Member, Place, AlertEvent, PermissionSummary domain models
│   ├── providers/         # Riverpod AppState & AppStateNotifier
│   ├── services/          # PermissionService & LocationService (Tracelet background tracking)
│   └── theme/             # AppColors & AppTheme (Material 3 + Google Fonts)
├── features/
│   ├── alerts/            # Activity & safety alert feed UI
│   ├── auth/              # AuthService, UserAccountModel, CircleModel
│   ├── history/           # Location timeline & history UI
│   ├── home/              # MainShellScreen & BottomNav widgets
│   ├── map/               # MapScreen & custom map painters
│   ├── onboarding/        # Role selection, Circle setup & PermissionGateScreen
│   ├── places/            # Places & geofencing management UI
│   ├── settings/          # Circle management, role switcher, permissions dashboard
│   └── sos/               # SOSOverlay emergency countdown widget
├── firebase_options.dart  # Firebase platform configuration
└── main.dart              # App entry point, Headless task callback & ProviderScope

test/
├── auth_service_test.dart # Unit tests for invite code formatting & domain model serialization
└── widget_test.dart       # Widget smoke test & Google Fonts setup
```

---

## 🧪 Verification & Health Checks

Run unit tests:
```bash
flutter test
```

Analyze code health:
```bash
flutter analyze
```

---

## 📱 How to Run & Test

1. **Check connected devices / emulators**:
   ```bash
   flutter devices
   ```

2. **Run the App**:
   ```bash
   flutter run
   ```

3. **Build Debug APK**:
   ```bash
   flutter build apk --debug
   ```
