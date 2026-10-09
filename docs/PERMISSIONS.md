# Role-specific permissions

Parent accounts receive a notification-only onboarding flow. They do not request foreground/background location, battery exemptions or OEM tracking settings. Their Settings summary shows notification permission. Child accounts retain the ordered foreground-location, background-location, notification and optional battery/OEM flow.

Permission requests coalesce while a dialog is pending, guard the account identity before applying results, and avoid updating disposed routes. Platform errors release the button and show a retry message. Optional OEM detection cannot block onboarding.

The main shell checks child permissions again on app resume. Missing foreground permission stops tracking and erases pending sharing data; restored permission starts tracking using the verified account/circle context. Asynchronous checks cannot start tracking for a replaced account. This requires physical Android validation for settings return, permission withdrawal during headless execution, process restart and battery restrictions.

Widget tests verify the parent flow makes no location/OEM calls, late responses do not update disposed state, and failed requests allow retry. These tests do not exercise Android's native permission dialogs.
