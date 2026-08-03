# Family Guard 🛡️

A modern, real-time family safety and location-sharing application built with **Flutter**, **Firebase**, and **Riverpod**, styled with a Material 3 design system.

Features real-time location tracking, geofence place alerts, movement history timeline, role-based parent/child experiences, and an instant SOS emergency panic system.

---

## ✨ Implemented Features & Modules

### 🔐 1. Authentication & Family Circle Management
- **Firebase Auth Service**: Email & Password sign up, sign in, sign out, and session state streams (`AuthService`).
- **Family Circle Creation & Joining**: Parents can create a new family circle (generates a unique 6-character invite code) or members can join an existing circle via invite code.
- **Role-Based Experiences**: Support for **Parent** (full circle monitoring, place creation, history inspection) and **Child** (location broadcasting, quick status updates, panic SOS trigger) roles.

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

### 🚨 6. Emergency SOS Panic System (`SOSOverlay`)
- **Full-Screen Emergency Overlay**: High-visibility red panic screen with a 3-second animated countdown to prevent accidental triggers.
- **Siren Simulation**: Triggers audible panic tone and emergency vibration feedback.
- **Circle Panic Dispatch**: Dispatches immediate high-priority emergency notifications with live GPS coordinates to all circle members.

### 🎨 7. Modern Material 3 Design System & Theme
- **Design Tokens**: Standardized color palette in `AppColors` (#EFF6FF soft blue, #3B82F6 primary blue, #EF4444 SOS red, #10B981 online green).
- **Typography**: Clean typography using Google Fonts **Nunito**.
- **Main Shell Screen (`MainShellScreen`)**: Fluid bottom navigation bar, top header avatar row, active circle badge, quick role toggle, and persistent floating SOS trigger button.

### 🗄️ 8. Firebase & Security Infrastructure
- **Firestore Security Rules (`firestore.rules`)**: Production-ready security rules covering user profiles, family circles, live locations, location history logs, places, place events, and SOS panic events.
- **FlutterFire Configuration (`lib/firebase_options.dart`)**: Auto-generated Firebase options for cross-platform integration.
- **Firebase Setup Guide (`How to setup Firebase.md`)**: Comprehensive guide for Firebase setup.

---

## 📁 Project Architecture & Structure

```
lib/
├── core/
│   ├── models/            # Member, Place, AlertEvent domain models
│   ├── providers/         # Riverpod AppState & AppStateNotifier
│   └── theme/             # AppColors & AppTheme (Material 3 + Google Fonts)
├── features/
│   ├── alerts/            # Activity & safety alert feed UI
│   ├── auth/              # AuthService, UserAccountModel, CircleModel
│   ├── history/           # Location timeline & history UI
│   ├── home/              # MainShellScreen & BottomNav widgets
│   ├── map/               # MapScreen & custom map painters
│   ├── onboarding/        # Role selection & Circle setup screens
│   ├── places/            # Places & geofencing management UI
│   ├── settings/          # Circle management, role switcher, permissions
│   └── sos/               # SOSOverlay emergency countdown widget
├── firebase_options.dart  # Firebase platform configuration
└── main.dart              # App entry point with ProviderScope
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
