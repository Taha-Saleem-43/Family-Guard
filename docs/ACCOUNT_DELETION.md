# Account deletion

For the active free backend, follow the [Workers guide](../workers/README.md).
Deletion saves its cleanup stage and resumes in bounded batches through signed
Worker jobs and the minute recovery sweep. Expiry uses ordinary cleanup writes.
The Cloud Functions/TTL deployment instructions below describe the original
backend implementation and are not the deployment path for Firebase Spark.

Authenticated users can request deletion from Settings or before joining a circle. Password verification is sent only to Firebase Auth. The callable receives the expected UID, requires recent authentication and atomically detaches membership, disables client access through a deletion tombstone and queues cleanup.

Deploy `requestAccountDeletion`, `processAccountDeletion`, and `retryAccountDeletions` together with the updated rules and indexes. Configure TTL for `accountDeletions.expireAt`. Pending jobs have no expiry; completed tombstones remain for two days to outlive cached credentials. The event worker retries failures; an hourly sweeper recovers pending jobs and expired ten-minute leases. Monitor pending age, failures and exhausted retries in production. No deployment is performed by local tests.

Cleanup disables Firebase Auth, removes the user's profile, personal history, current location, sent SOS alerts, created places, attributed event records and invite attempts, then deletes the Auth user. An empty circle also loses its private invitations and circle-scoped data. Other members retain their accounts and personal histories. A surviving circle with no parent is marked `requiresParent`; joining through a valid parent invitation clears that flag. A dedicated parent handoff/leave flow remains release work.

Native location storage, geofences and scoped local preferences are cleared after acceptance. Cleanup failure is shown separately from a successful backend request. Tests inject a mock Auth adapter, so emulator tests cannot disable or delete production Auth users.

Firestore now uses memory-only caching in foreground and headless sessions. A one-time startup migration removes caches and pending Firestore writes from older versions before mounting account screens. Cleanup failure blocks account UI and offers retry; an already-running legacy headless client may require closing and reopening the app. The migration is recorded only after successful cleanup. No offline disk durability is provided by Firestore; durable native upload recovery remains separate work. Memory held by an existing SDK client is not securely overwritten by this operation.

Release gates: staging end-to-end deletion, startup migration and native cleanup on devices (including boot/headless concurrency), operational monitoring, a public web deletion-request URL and a published policy explaining retention and any legally required exceptions. Clearing app storage remains the fallback for native cache failure.
