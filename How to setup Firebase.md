# How to Setup Firebase for Family Guard 🛡️

A step-by-step, beginner-friendly guide to setting up Firebase for the **Family Guard** Flutter app.

---

## 📋 Prerequisites

Make sure you have:
1. A **Google Account**.
2. **Node.js** installed on your computer (for Firebase CLI tools).
3. Flutter installed and configured.

---

## 🛠️ Step 1: Create a New Firebase Project

1. Open your browser and go to the **[Firebase Console](https://console.firebase.google.com/)**.
2. Click **"Add project"** (or **"Create a project"**).
3. Enter your project name: `family-guard-app` (or any name you choose).
4. Click **Continue**.
5. *(Optional)* Turn off Google Analytics for now (or leave it on), then click **Create Project**.
6. Wait 10 seconds until it says *"Your new project is ready"*, then click **Continue**.

---

## 🔑 Step 2: Enable Email Authentication

1. In the left side menu of your Firebase Console, click **Build** $\rightarrow$ **Authentication**.
2. Click **Get Started**.
3. Under the **Sign-in method** tab, click **Email/Password**.
4. Toggle the **Enable** switch to `ON` (Leave "Email link (passwordless sign-in)" unchecked).
5. Click **Save**.

---

## 🗄️ Step 3: Create Cloud Firestore Database & Apply Security Rules

1. In the left side menu, click **Build** $\rightarrow$ **Firestore Database**.
2. Click **Create database**.
3. Choose your database location (e.g., `nam5 (us-central)` or a location near you), then click **Next**.
4. Select **Start in production mode**, then click **Create**.
5. Once your database is created, click the **Rules** tab at the top.
6. Replace all existing text in the rules editor with the exact content from our project's [`firestore.rules`](file:///d:/Flutter_Projects/copy/Family-Guard/firestore.rules):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    function isParentInCircle(circleId) {
      return isAuthenticated() && 
        getUserData().circleId == circleId && 
        getUserData().role == 'parent';
    }

    function isMemberOfCircle(circleId) {
      return isAuthenticated() && getUserData().circleId == circleId;
    }

    match /users/{userId} {
      allow read: if isAuthenticated() && (
        isOwner(userId) || 
        getUserData().circleId == resource.data.circleId
      );
      allow create: if isAuthenticated() && isOwner(userId);
      allow update: if isAuthenticated() && isOwner(userId) && 
        (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']));
    }

    match /circles/{circleId} {
      allow read: if isMemberOfCircle(circleId);
      allow create: if isAuthenticated();
      allow update: if isParentInCircle(circleId);
    }

    match /locations/{userId} {
      allow write: if isOwner(userId);
      allow read: if isAuthenticated() && (
        isOwner(userId) || 
        getUserData().role == 'parent'
      );
    }

    match /locationHistory/{userId}/points/{pointId} {
      allow write: if isOwner(userId);
      allow read: if isAuthenticated() && (
        isOwner(userId) || 
        getUserData().role == 'parent'
      );
    }

    match /places/{placeId} {
      allow read, write: if isAuthenticated() && isMemberOfCircle(resource.data.circleId);
      allow create: if isAuthenticated();
    }

    match /placeEvents/{eventId} {
      allow read, write: if isAuthenticated();
    }

    match /sosEvents/{eventId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

7. Click **Publish**.

---

## ⚡ Step 4: Link Firebase to your Flutter App automatically (FlutterFire CLI)

Instead of manually editing Android/iOS config files, use **FlutterFire CLI** to configure everything automatically in 1 minute!

1. Open PowerShell or Terminal in your project directory:
   `D:\Flutter_Projects\copy\Family-Guard`

2. Install Firebase CLI & FlutterFire CLI (if you haven't already):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```

3. Log in to Firebase:
   ```bash
   firebase login
   ```
   *(This opens a browser window for you to log in to your Google Account).*

4. Run the automatic configuration command:
   ```bash
   flutterfire configure
   ```

5. Select your project (`family-guard-app`) using the arrow keys and press **Enter**.
6. Select the platforms (`android`, `ios`) and press **Enter**.

> 🎉 **Done!** This automatically generates `lib/firebase_options.dart` and links your Android app (`google-services.json`).

---

## 🧪 Step 5: Verify Firebase Setup in Flutter

1. Open `lib/main.dart` and initialize Firebase inside `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: FamilyGuardApp(),
    ),
  );
}
```

2. Test your setup by running:
   ```bash
   flutter run
   ```

---

## ✅ Quick Verification Checklist

- [ ] Project created in Firebase Console.
- [ ] Email/Password Authentication enabled.
- [ ] Firestore Database created and `firestore.rules` published.
- [ ] `flutterfire configure` command ran successfully.
- [ ] `lib/firebase_options.dart` file generated.
