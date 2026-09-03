import XCTest
@testable import GopherForge

/// The screen and the entitlement have to agree.
///
/// They did not: the entitlement deliberately left Game Center out, and the
/// Achievements screen still offered "Connect Game Center" — a button that
/// cannot succeed in a signed build, next to a privacy policy saying the
/// feature is unavailable in this release. Whichever way that is resolved, it
/// has to be resolved in both places at once, and nobody remembers to.
final class GameCenterAvailabilityTests: XCTestCase {
    private func entitlements() throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "GopherForge/GopherForge.entitlements")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testTheUIIsOfferedExactlyWhenTheEntitlementIsClaimed() throws {
        let document = try entitlements()
        // The name appears in the explanatory comment either way, so the test
        // asks whether it is declared as a key rather than merely mentioned.
        let isClaimed = document.contains("<key>com.apple.developer.game-center</key>")

        XCTAssertEqual(
            GameCenterAvailability.isEnabled, isClaimed,
            isClaimed
                ? "the entitlement is claimed, so the screen should offer Game Center"
                : "the entitlement is not claimed, so nothing may offer signing in"
        )
    }
}
