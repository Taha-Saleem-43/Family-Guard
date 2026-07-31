# Family Guard 🛡️

A family-safety app featuring real-time location sharing, place alerts (geofencing), location history, and SOS/emergency alerts with parent and child role experiences.

---

## 🚀 Current Implementation Status (Phase 1 — Step 0)

### What is Implemented & Ready to Test:

1. **App Shell & Design Theme**:
   - Material 3 theme powered by **Nunito** (Google Fonts).
   - Figma design tokens implemented in `AppColors` (palette featuring `#EFF6FF` soft background, `#3B82F6` primary blue, teal, SOS red, and family member pin colors).
   - `ProviderScope` initialized for Riverpod state management.
   - Clean initial screen with branded shield logo and themed layout.

2. **Core Data Models**:
   - `Member` model (supports parent/child roles, pin colors, location coordinates, battery %, movement state, stale tracking indicator).
   - `Place` model (supports categories: home, school, work, custom, geofence radius).
   - `AlertEvent` model (arrival/departure logs).

3. **Android Platform Configuration**:
   - `minSdkVersion`: **26** (Android 8.0+)
   - `targetSdkVersion`: **34** (Android 14)
   - `compileSdkVersion`: **34**
   - Manifest configured with permission skeleton for background location tracking, foreground services, boot receiver, notifications, and battery optimization exemptions.

4. **All Core Dependencies Configured**:
   - Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`)
   - Maps (`google_maps_flutter`)
   - State Management (`flutter_riverpod`)
   - Local Storage & Sync (`sqflite`, `shared_preferences`)
   - Permissions & Notifications (`permission_handler`, `flutter_local_notifications`)
   - Network & Utilities (`dio`, `intl`, `equatable`)

---

## 📱 How to Test on Mobile / Emulator

Yes! You can run and test the app right now on an Android physical device or emulator.

### Prerequisites
- Android Studio / Android SDK installed.
- USB Debugging enabled on your Android physical device, OR an Android Emulator created (API 26+).

### Step-by-Step Instructions

1. **Check connected devices**:
   ```bash
   flutter devices
   ```

2. **Run the app on your mobile device/emulator**:
   ```bash
   flutter run
   ```
   *(If multiple devices are connected, select your target device using `flutter run -d <device_id>`)*

3. **Build Debug APK for manual installation** (Optional):
   ```bash
   flutter build apk --debug
   ```
   The APK will be generated at:
   `build/app/outputs/flutter-apk/app-debug.apk`

---

## 🧪 Verification Commands

To verify code health:
```bash
flutter analyze
flutter test
```
