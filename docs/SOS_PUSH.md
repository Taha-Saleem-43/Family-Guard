# SOS push delivery

The active free deployment uses the [Workers backend](../workers/README.md),
signed background jobs, pending-fanout recovery and ordinary expiry cleanup.
Use `firebase.spark.json` for Firestore deployment. The Functions/TTL deployment
instructions below apply to the original Firebase backend configuration.

Deploy the matching client, rules, indexes and functions in staging first:
`registerPushDevice`, `unregisterPushDevice`, `acknowledgeSosPush`, `enqueueSosPush`,
`deliverSosPush`, and `retrySosPushDeliveries`. Firebase Cloud Messaging must be enabled
and App Check registered. Android creates a high-importance emergency channel before
registering its token. iOS also needs its APNs configuration. No production messages
are sent by local tests; the Messaging adapter is mocked.

Registration is private and bounded to ten active installations per account. A random
256-bit installation secret proves ownership; its SHA-256 prefix is the public device
ID. Persistent versions prevent older requests from reclaiming a device after account
switching or logout. Token refresh and daily registration renewal maintain a 30-day
expiry. Tokens and secret hashes are not indexed or exposed to clients. Android backup
is disabled for this sensitive local state; verify vendor device-transfer behavior.

The alert-created worker atomically creates per-device jobs once, excluding the sender.
Workers recheck current account, membership, deletion state, token ownership and alert
status before sending. Changed tokens for the same installation/account are supported.
Transient failures retry with backoff; expired leases are recovered by a minute sweeper.
Invalid tokens are disabled without deleting newer replacements. The delivery window is
15 minutes and FCM message TTL is five minutes. Configure TTL on `pushDevices.expireAt`
and `sosPushDeliveries.expireAt`; delivery records expire after two days.

Push text is generic and carries no member name or coordinates. Opening verifies the
signed-in recipient and circle with the backend before navigation. The app presents
emergencies from confirmed Firestore state. Foreground/background receipt callbacks
record best-effort receipt, and tapping a notification records opening. The sender's
delivery stream separates FCM acceptance from receipt/opening. Neither means help is
on the way. Notification messages may be handled by the OS without a background Dart
callback, so missing receipt acknowledgements do not prove non-delivery.

Delivery is at least once: a crash after FCM acceptance can repeat a send. Android tags
and APNs collapse IDs replace repeated notifications; a shared Android collapse key
coalesces queued generic emergency signals. Opening the app restores all active alerts.
There is no device acknowledgement guarantee, and force-stopped apps, denied permissions,
offline devices, platform power policies and missing APNs/FCM setup can prevent receipt.
Offline logout attempts backend revocation and local token deletion but cannot guarantee
remote revocation; notification text therefore remains generic and taps remain account-fenced.

Release gates: real-device foreground/background/terminated/force-stop tests, permission
revocation, token rotation, account switching, delayed/resolved pushes, boot concurrency,
monitoring queue age/failures, staging IAM/index/TTL validation and load benchmarks.
Device counts represent installations, not distinct people. The emulator does not prove
actual FCM transport or native notification behavior.
