# Live account scope changes

Parent member queries use the current circle's validated roster, with at most twenty document IDs. Roster changes and authority errors cancel the previous profile query. Rules require both the requesting member and any viewed peer profile/history to belong to the actual roster; stale profile circle links cannot restore access. Deploy matching clients before enabling these stricter query rules. Older broad `users where circleId` queries are intentionally rejected.

While the main app is open, an owner-profile listener accepts confirmed server snapshots only. Changes to the account's role, circle or deletion state clear invite codes and private views immediately, pause tracking and invalidate earlier circle callbacks. Name-only updates retain the active tab. A changed sharing scope returns to consent/permission onboarding; completing it opens a fresh profile listener.

The MaterialApp navigator is keyed by the active account/circle/role scope. Leaving that scope clears outstanding dialogs and routes, including private detail views. Onboarding keeps its own stable key during ordinary circle creation so the invite-code screen remains available. Existing authenticated accounts without a circle resume circle setup instead of being asked to register again.

Circle access loss retains the authenticated UID while blocking private screens. A later server profile detached from the lost circle can resume setup; stale data from the inaccessible circle cannot restore access. Both the paused-account and verification-failure screens retain retry, sign-out and account deletion controls. Deletion uses the current SDK identity even when the profile could not be loaded, and rechecks that identity after confirmation. Firebase authorization remains the authority for every backend operation.

Creating or joining a new circle atomically removes previous live coordinates, movement, capture watermarks and battery fields from the profile and removes the legacy live-location document. Redeeming an invite again within the same circle preserves its current live fix. Historical points keep their original circle scope; they are not reassigned to new members.

Callbacks are fenced by subscription generation and current Firebase UID. An old account's late snapshot cannot change a new or signed-out session. Onboarding operations check mounted state before applying asynchronous SDK results.

Unit tests cover role changes, private invite clearing, name-only updates, account replacement, signed-out snapshots and deleted profiles. Native tracking stop/start races and remote changes while offline require additional lifecycle and physical-device validation; immediate remote shutdown during an outage is not guaranteed.
