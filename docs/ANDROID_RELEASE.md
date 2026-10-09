# Android release configuration

Feature branch: `taha/android-release`. Debug builds keep the development ID until an owner-approved permanent ID is configured. Production release builds require that ID and a real upload keystore; they cannot fall back to debug signing.

## Local setup

1. Confirm the permanent Android application ID with the owner, then set `FAMILY_GUARD_APPLICATION_ID` for the build process. It must match the Android app registered in the intended Firebase project and its `google-services.json`. The Kotlin namespace can remain separate from the application ID.
2. Copy `android/key.properties.example` to ignored `android/key.properties`, filling in the upload keystore path, alias and passwords locally. Keep an independent secure backup of the upload keystore. Never commit credentials or keystores.
3. Use the already-installed Flutter/JDK/Android SDK. Set `GRADLE_USER_HOME` to `.cache/gradle` and `PUB_CACHE` to `.pub-cache` before dependency resolution or builds so new downloads stay in the checkout. Do not install or upgrade global SDK tools.
4. Build the signed app bundle with `flutter build appbundle --release`. `validateReleaseConfiguration` rejects placeholder IDs, missing signing fields and nonexistent keystores. This verifies configuration presence; signing and Play validation must still succeed.

The configuration pins build tools 36.1.0 and disables automatic SDK installation during builds. Install required SDK/NDK components explicitly in an approved local SDK before building. GitHub's Android job provisions its SDK components inside the checkout cache, compiles an ARM64 debug APK and checks that a development identity is rejected for release. This job does not create a production keystore or a signed release bundle.

## Required release verification

The app targets Android 16/API 36. [Google's current target API requirement](https://developer.android.com/google/play/requirements/target-sdk) applies to new app submissions from August 31, 2026. Raising the target changes Android behavior and requires real-device verification, particularly permissions, edge-to-edge layout, foreground tracking and boot handling.

Confirm Android's 16 KB page-size compatibility for every bundled native library, validate the actual AAB and its upload certificate, and test supported devices before distributing it. Neither Dart tests nor changing `targetSdk` proves native compatibility.

The account/package-ID/signing/Firebase configuration, backend deployment, privacy disclosures, account deletion and device testing remain release gates. No keystore or permanent release identity has been invented or generated as part of this change.
