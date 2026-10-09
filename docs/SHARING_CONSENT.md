# Device location disclosure

Children explicitly acknowledge the background-location disclosure before the permission flow. The device records its disclosure version, circle and Firebase sign-in time. Existing Android grants do not substitute for this acknowledgement. New sign-ins and circle changes require confirmation again; an ordinary restart of the same sign-in preserves it.

Restoration keeps a child at onboarding when acknowledgement is missing. Native tracking independently checks it before activating any sharing context. Parents do not need location consent. Logout and account deletion erase the UID-scoped acknowledgement. This device record is a functional gate, not legal proof of age or parental authority.

Physical-device tests must confirm first install, upgrades, existing grants, shared-device sign-ins and consent followed by permission denial. Production privacy disclosures and Play Console declarations remain release requirements.
