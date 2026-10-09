# Live account scope changes

While the main app is open, an owner-profile listener accepts confirmed server snapshots only. Changes to the account's role, circle or deletion state clear invite codes and private views immediately, pause tracking and invalidate earlier circle callbacks. Name-only updates retain the active tab. A changed sharing scope returns to consent/permission onboarding; completing it opens a fresh profile listener.

The MaterialApp navigator is keyed by the active account/circle/role scope. Leaving that scope clears outstanding dialogs and routes, including private detail views. Onboarding keeps its own stable key during ordinary circle creation so the invite-code screen remains available. Existing authenticated accounts without a circle resume circle setup instead of being asked to register again.

Circle access loss retains the authenticated UID while blocking private screens. A later server profile detached from the lost circle can resume setup; stale data from the inaccessible circle cannot restore access. Deletion/read denial shows a paused-account screen with verification retry and sign-out actions. Firebase authorization remains the authority for every backend operation.

Callbacks are fenced by subscription generation and current Firebase UID. An old account's late snapshot cannot change a new or signed-out session. Onboarding operations check mounted state before applying asynchronous SDK results.

Unit tests cover role changes, private invite clearing, name-only updates, account replacement, signed-out snapshots and deleted profiles. Native tracking stop/start races and remote changes while offline require additional lifecycle and physical-device validation; immediate remote shutdown during an outage is not guaranteed.
