# UI refinement

The main screens share a calm teal palette, clearer heading/subtitle hierarchy, filled form fields and consistent primary buttons. Muted text has stronger contrast. The native Material navigation bar keeps every destination labelled and exposes selected destinations to accessibility services.

SOS has a persistent labelled entry point above navigation on every main screen. It opens the existing countdown/confirmation flow. It no longer competes with map controls as a floating map-only button.

The parent map uses a scrollable roster with explicit missing/outdated/SOS status, a recenter action and visible map attribution. The child map separates its status from parent-only filters and links directly to sharing settings. A captured fix is not described as proof of upload or delivery.

Place editing and notification controls are parent-only. Children can read saved places and notification status. Category filters remain horizontally scrollable; place controls and member counts accommodate larger text. Place and activity errors offer retries without exposing backend exception text. Account recovery and empty states use scrollable feedback panels.

Widget regressions cover narrow screens, larger text, role-specific controls, retry actions and navigation/SOS interaction. The optional preview export renders production widgets with fixture data; it uses fonts from an existing local Flutter SDK as a visual-review fallback and performs no download. Device checks remain necessary for actual fonts, keyboard/insets, screen readers, Android edge-to-edge and map tiles.
