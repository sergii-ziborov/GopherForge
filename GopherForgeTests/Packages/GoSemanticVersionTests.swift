import XCTest
@testable import GopherForge

final class GoSemanticVersionTests: XCTestCase {
    func testAReleaseParsesAndOrders() throws {
        let one = try XCTUnwrap(GoSemanticVersion("v1.9.4"))
        let two = try XCTUnwrap(GoSemanticVersion("v2.0.0"))
        XCTAssertEqual(one.major, 1)
        XCTAssertEqual(one.minor, 9)
        XCTAssertEqual(one.patch, 4)
        XCTAssertFalse(one.isPreRelease)
        XCTAssertTrue(one < two)
    }

    func testAPreReleaseSortsBelowItsRelease() throws {
        let rc = try XCTUnwrap(GoSemanticVersion("v2.0.0-rc.1"))
        let release = try XCTUnwrap(GoSemanticVersion("v2.0.0"))
        XCTAssertTrue(rc.isPreRelease)
        XCTAssertTrue(rc < release)
        XCTAssertEqual(GoSemanticVersion.newestStable(["v2.0.0-rc.1", "v1.9.4"]), "v1.9.4")
        XCTAssertEqual(GoSemanticVersion.newestStable(["v2.0.0-rc.1"]), "v2.0.0-rc.1")
    }

    func testBuildMetadataDoesNotAffectOrder() throws {
        let first = try XCTUnwrap(GoSemanticVersion("v1.2.3+incompatible"))
        let second = try XCTUnwrap(GoSemanticVersion("v1.2.3"))
        XCTAssertFalse(first < second)
        XCTAssertFalse(second < first)
        XCTAssertEqual(first.patch, 3)
    }

    func testUnparseableVersionsStayAtTheEnd() {
        XCTAssertNil(GoSemanticVersion("1.2.3"))
        XCTAssertNil(GoSemanticVersion("latest"))
        XCTAssertEqual(
            GoSemanticVersion.sortedNewestFirst(["v1.0.0", "not-a-version", "v1.1.0"]),
            ["v1.1.0", "v1.0.0", "not-a-version"]
        )
    }

    func testMissingMinorAndPatchDefaultToZero() throws {
        let version = try XCTUnwrap(GoSemanticVersion("v2"))
        XCTAssertEqual(version.minor, 0)
        XCTAssertEqual(version.patch, 0)
    }
}
