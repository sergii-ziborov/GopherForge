# Game Center

> **Current state: off, and not shown.** The entitlement is not claimed and
> `GameCenterAvailability.isEnabled` is `false`, so the Achievements screen
> shows local badges only. The two are checked against each other by
> `GameCenterAvailabilityTests`: claiming the entitlement without flipping the
> flag, or the reverse, fails the build rather than shipping a Connect button
> that cannot connect. Everything below describes what enabling it involves.

The achievements in this app are earned, stored and shown locally. Game Center
mirrors them for people who want that, and the app works identically for people
who do not.

## What is written

`GameCenterService` decides what is reported and when; `LiveGameCenterReporter`
is the only part that touches GameKit, which is why the rules can be tested
without signing anybody in. Every badge is reported as a percentage rather than
a flag, so one halfway there shows a bar in Game Center too.

Two decisions are worth stating.

**Sign-in is a button, never automatic.** Authenticating presents Apple's own
sheet over whatever the person was looking at, and being asked to sign in to
something for looking at a list is how people close an app. The Achievements
screen mirrors progress silently for a player Game Center already knows, and
otherwise offers to connect.

**Game Center is a mirror, not the record.** Nothing depends on it. Declining,
being offline, or never enabling it changes nothing about what the app tracks
or shows.

## What is not enabled, and why

The `com.apple.developer.game-center` entitlement is **deliberately absent from
`GopherForge.entitlements`.**

Declaring it makes every device build fail — the provisioning profile does not
carry the capability, and adding it requires enabling Game Center for the App ID
in the Apple Developer portal with a signed-in account. That is not something a
source tree can do, and a repository that does not build is a worse trade than
a feature that waits.

The code is complete either way. Until the capability is enabled the app reports
Game Center as unavailable, and if a report is attempted it says exactly why
rather than looking successful.

## Turning it on

1. In Xcode, select the GopherForge target → Signing & Capabilities → **+
   Capability** → **Game Center**. This adds the entitlement and regenerates
   the profile.
2. In App Store Connect, create an achievement for each badge with the
   identifier `com.sergiiziborov.GopherForge.<id>`, where `<id>` is the badge's
   own id from `AchievementCatalog` — `first.build`, `ten.runs`, `first.quiz`
   and the rest. `GameCenterServiceTests` pins the prefix and their uniqueness.
3. Build to a device and sign in from the Achievements screen.

Step 2 is the one that is easy to half-do. An identifier that does not exist in
App Store Connect is refused at report time, and the app will say so.
