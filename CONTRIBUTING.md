# Development workflow

Keep `main` releasable. Develop on `codex/<feature>` branches, review the code, run relevant checks and push each feature to its respective branch. Do not open pull requests unless the owner explicitly requests one. Merge into `main` only when the owner requests it. Cut `release/<version>` for final device verification and release-only fixes. Do not put secrets, keystores or service-account credentials in Git.

Group commits by behavior: authorization/backend, session lifecycle, tracking, history, notifications and release configuration. Every feature needs meaningful regression tests for its own behavior and failure paths. Backend rules changes require emulator tests. Background tracking and notification changes also require physical-device checks.

## Structure

- `lib/features/<feature>/`: presentation, providers, domain and service code owned by that feature.
- `lib/core/`: genuinely shared models, services and theme; avoid importing presentation code into domain services.
- `functions/`: authoritative membership, private invites and backend event processing.
- `test/`: Flutter regression tests and Firestore security integration tests.
- `.github/workflows/`: automatic verification on pull requests and feature/release branch pushes.

Prefer injected services and clocks at boundaries. Treat Firebase Auth as the identity authority; preferences only cache display data. Membership and roles are backend-owned. Keep one upload policy shared by foreground and headless execution. Separate mock fixtures from production empty/error states.

## Local verification

```sh
flutter pub get
flutter analyze
flutter test --coverage
npm ci --ignore-scripts
npm run test:backend
npm run test:rules
npm ci --prefix functions --ignore-scripts
npm run test:membership
```

Rules tests use a local `demo-family-guard` project and never deploy rules. Java 21 and Node 22 are needed for backend verification. CI runs the same checks. A passing test suite does not establish battery life or delivery reliability on devices.

On Windows, `scripts/verify.ps1` sets project-local Dart, npm and emulator cache paths. Do not install global npm tools, upgrade the shared Flutter SDK or use system Python packages. If Python is later needed, use a repository-local `.venv`. Existing SDKs and already-resolved dependencies can be reused read-only without downloading them again.

## Feature completion

A feature is ready when its UI, storage, authorization, failures and tests work together. Record migration/deployment requirements in repository release documentation. Do not claim a Play Store release is ready until the signed build, real-device checklist, account deletion, privacy disclosures and Play Console requirements are complete.
