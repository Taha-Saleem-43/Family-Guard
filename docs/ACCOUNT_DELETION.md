# Account deletion

Authenticated users can request deletion from Settings or before joining a circle. Password verification is sent only to Firebase Auth. The callable receives the expected UID, requires recent authentication and atomically detaches membership, disables client access through a deletion tombstone and queues cleanup.

Deploy `requestAccountDeletion`, `processAccountDeletion`, and `retryAccountDeletions` together with the updated rules and indexes. Configure TTL for `accountDeletions.expireAt`. Pending jobs have no expiry; completed tombstones remain for two days to outlive cached credentials. The event worker retries failures; an hourly sweeper recovers pending jobs and expired ten-minute leases. Monitor pending age, failures and exhausted retries in production. No deployment is performed by local tests.

Cleanup disables Firebase Auth, removes the user's profile, personal history, current location, sent SOS alerts, created places, attributed event records and invite attempts, then deletes the Auth user. An empty circle also loses its private invitations and circle-scoped data. Other members retain their accounts and personal histories. A surviving circle with no parent is marked `requiresParent`; joining through a valid parent invitation clears that flag. A dedicated parent handoff/leave flow remains release work.

Native location storage, geofences and scoped local preferences are cleared after acceptance. Cleanup failure is shown separately from a successful backend request. Tests inject a mock Auth adapter, so emulator tests cannot disable or delete production Auth users.

Release gates: staging end-to-end deletion, native cleanup on devices, Firestore offline-cache erasure without disrupting another account, operational monitoring, a public web deletion-request URL and a published policy explaining retention and any legally required exceptions. Current local cleanup covers Tracelet and scoped preferences; it does not erase Firestore's persistent cache. Clearing app storage removes that cache.
