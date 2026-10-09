# Saved places and confirmed activity

Parents manage places through `savePlace`, `deletePlace` and `togglePlaceNotifications`. The callables check account identity, deletion state, parent role and current membership inside transactions. They validate geometry and names, preserve creator identity, and enforce 50 places per circle even when additions race. Independent notification toggles update only their selected field.

The public place collection supplies the existing app screen. An atomic server-maintained configuration in `circles/{circle}/private/places` supplies location processing. This reduces steady-state geometry reads from one document per saved place to one configuration document. One bounded presence document stores the child's state for all places, reducing presence reads and writes to one per fix. Initial configuration bootstraps valid legacy places once; legacy circles above the cap require cleanup rather than silent omission.

Location ingestion updates presence and creates events in the same transaction as the new live location. Initial observations establish a baseline. A 25-metre boundary buffer plus two observations separated by at least 30 seconds confirm crossings. Geometry edits reset the baseline. Arrival/departure settings suppress events while continuing to maintain presence. Offline historical fixes do not generate present-day crossings, and deterministic event IDs prevent retry duplicates. Sampling and OS scheduling can delay or miss short visits; these events do not establish a person's safety.

The activity screen merges confirmed place events with SOS history. Place-feed failure keeps SOS visible and hides stale place data. Parents see their circle's events; children see only their own. Presence is backend-only. Events and presence expire after 30 days. Account deletion removes personal presence/events and atomically removes owned places from both public records and processing configuration.

`ingestLocations` also enforces a 600-fix per minute account budget before reading history or processing places. Recovery backs off on resource exhaustion. This is a defensive ceiling, not a measured capacity promise.

## Deployment and remaining delivery work

Deploy callables and configuration/indexes before rules that reject legacy direct place writes. Upgrade clients together. No production deployment has been performed. Place events also enqueue durable notifications for current parents. Delivery rechecks role, membership, device registration and event freshness; events older than fifteen minutes expire. Retries, leases and acknowledgements use the same delivery machinery as SOS, with a separate private queue and a normal-priority Android activity channel. Lock-screen content contains no member/place name or coordinates. Taps require server acknowledgement before opening activity. Accepted FCM requests do not prove device receipt, and short visits can still be missed.

## Verification

`npm run test:places` tests parent authority, capacity races, independent toggles, initial baselines, jitter, confirmed crossings, suppressed events and geometry changes in the Firestore emulator. Rules tests check child/parent visibility and forged-event rejection. Account deletion tests check processing-configuration cleanup. A widget regression verifies that place-feed failure does not hide SOS or retain stale place events.

Physical-device validation remains required for GPS boundary behaviour, timing, battery consumption, airplane-mode recovery and signed builds. Synthetic test coordinates do not prove real-world geofence accuracy.
