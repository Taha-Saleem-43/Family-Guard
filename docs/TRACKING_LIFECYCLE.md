# Tracking lifecycle boundaries

Native starts and stops run through one ordered coordinator per foreground isolate. Each operation carries its requesting UID. A pending old-account start is stopped before a queued replacement-account start, and late cleanup for an old UID cannot stop the new active tracker. Verification/native calls have ten-second deadlines so an unresponsive adapter cannot indefinitely block queued work.

Starts verify the current server profile, child role, circle membership and deletion state before activating a sharing context. Parent entry stops lingering native tracking. Initialization coalesces and registers foreground callbacks once; debug-log errors cannot prevent persistence. Failed persistence remains eligible for bounded native recovery.

Native fixes displayed in the UI must also belong to the active child sharing scope and its current sign-in/context start. Late old-account or old-circle callbacks cannot refresh the replacement member. Display freshness uses capture time. Settings movement badges do not offer controls that fabricate activity or speed.

Sharing contexts must start after the Firebase user's latest sign-in. A new sign-in invalidates an old enabled context even if earlier cleanup failed. Foreground/headless ingestion and flushing reject prior sign-in contexts. An ordinary process restart preserves a context belonging to the same sign-in, so valid offline history can still recover.

The ingestion callable also checks the authenticated token's `auth_time` against the sharing start and rejects fixes captured before that context. The upload lease captures its sharing start atomically with its fixes. Deploy this callable with the matching client; older clients without a sharing start cannot ingest locations.

Sign-out attempts scoped tracking cleanup, then still clears Firebase authentication if native stopping reports an error. The error is returned after authentication/session cleanup. It never signs out a replacement account that appeared while cleanup was pending. Account deletion continues to require sharing pause before accepting the destructive request.

Tests cover pending native starts, late old-account stops, failed cleanup, authentication changes during verification, revoked membership and hung verification deadlines. Real SQLite tests cover newer sign-ins invalidating stale sessions. Native method deadlines do not cancel an already-running Android operation; actual service termination, headless registration, force-stop and reboot behaviour remain physical-device release gates.
