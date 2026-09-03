import Foundation

/// Whether this build may show anything about Game Center.
///
/// The entitlement is deliberately not claimed — see the note in
/// `GopherForge.entitlements` and `docs/GAME-CENTER.md` — so authentication
/// cannot succeed in a signed build. The screen offered "Connect Game Center"
/// anyway, which is a button that cannot do what it says: a broken feature to
/// anyone who taps it, and a contradiction to a reviewer reading a privacy
/// policy that states the feature is unavailable in this release.
///
/// One flag rather than deleted code, because the answer changes together with
/// the entitlement and the achievement identifiers, and the day it does this is
/// the single line to move. `GameCenterAvailabilityTests` fails if the two
/// disagree.
enum GameCenterAvailability {
    static let isEnabled = false
}
