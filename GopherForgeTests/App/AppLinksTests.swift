import XCTest
@testable import GopherForge

/// Settings links should always open over HTTPS.
final class AppLinksTests: XCTestCase {
    func testExternalLinksAreHTTPS() {
        for url in [AppLinks.privacyPolicy, AppLinks.support, AppLinks.writeReview] {
            XCTAssertEqual(url.scheme, "https", "\(url) is not https")
            XCTAssertNotNil(url.host, "\(url) has no host")
        }
    }

    /// A privacy policy URL that points at the repository root, or at a page
    /// that is not the policy, passes a smoke test and fails a review.
    func testThePrivacyLinkPointsAtThePolicy() {
        XCTAssertTrue(
            AppLinks.privacyPolicy.absoluteString.hasSuffix("PRIVACY.md"),
            "the privacy link should open the policy itself"
        )
    }

    func testTheVersionSummaryIsReadable() {
        let summary = AppLinks.versionSummary
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("("), "the build number belongs beside the version: \(summary)")
    }
}
