import XCTest
@testable import GopherForge

final class GoToolchainLocatorTests: XCTestCase {
    func testLanguageVersionDropsThePatch() {
        XCTAssertEqual(GoToolchainLocator.languageVersion(fromGoVersion: "go1.24.3"), "go1.24")
        XCTAssertEqual(GoToolchainLocator.languageVersion(fromGoVersion: "1.22.0"), "go1.22")
        XCTAssertEqual(GoToolchainLocator.languageVersion(fromGoVersion: "go1.21"), "go1.21")
        XCTAssertEqual(GoToolchainLocator.languageVersion(fromGoVersion: "not-a-version"), "go1.21")
    }

    func testABundleWithoutAToolchainIsMissing() {
        let locator = GoToolchainLocator(bundle: Bundle(for: Self.self))
        XCTAssertEqual(locator.probe(), .missing)
        XCTAssertNil(locator.resolve(prepareLibrary: false))
    }

    func testTheMissingStatusIsNeverReady() {
        XCTAssertFalse(ToolchainStatus.missing.isReady)
        XCTAssertEqual(ToolchainStatus.missing.toolSize, 0)
        XCTAssertTrue(ToolchainStatus.missing.label.lowercased().contains("missing"))
    }
}
