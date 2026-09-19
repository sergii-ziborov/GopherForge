import XCTest
@testable import GopherForge

final class GoTestResultTests: XCTestCase {
    private func result(_ outcome: GoTestResult.Outcome) -> GoTestResult {
        GoTestResult(
            name: "TestX",
            packagePath: "playground",
            outcome: outcome,
            elapsedSeconds: 0.01,
            output: ""
        )
    }

    func testCountsIgnoreSkippedWhenAskingIfAllPassed() {
        let mixed = [result(.passed), result(.failed), result(.skipped)]
        XCTAssertEqual(mixed.passedCount, 1)
        XCTAssertEqual(mixed.failedCount, 1)
        XCTAssertFalse(mixed.allPassed)
    }

    func testAnEmptyListHasNotPassed() {
        let none: [GoTestResult] = []
        XCTAssertFalse(none.allPassed)
        XCTAssertEqual(none.passedCount, 0)
    }

    func testAllPassedMeansNoFailuresInANonEmptyList() {
        XCTAssertTrue([result(.passed)].allPassed)
        XCTAssertTrue(
            [result(.skipped)].allPassed,
            "a skip is not a failure; go test treats that package as ok"
        )
        XCTAssertFalse([result(.passed), result(.failed)].allPassed)
    }
}
