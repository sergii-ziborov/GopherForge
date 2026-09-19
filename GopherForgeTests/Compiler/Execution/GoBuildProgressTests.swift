import XCTest
@testable import GopherForge

final class GoBuildProgressTests: XCTestCase {
    func testASingleStepHasNoFractionLabel() {
        let progress = GoBuildProgress(label: "gofmt", step: 1, totalSteps: 1)
        XCTAssertEqual(progress.summary, "gofmt")
        XCTAssertEqual(progress.fraction, 1)
    }

    func testAMultiStepSummaryCountsFromOne() {
        let progress = GoBuildProgress(label: "compile fmt", step: 3, totalSteps: 7)
        XCTAssertEqual(progress.summary, "compile fmt · 3 of 7")
        XCTAssertEqual(progress.fraction, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testZeroTotalIsSafe() {
        let progress = GoBuildProgress(label: "setup", step: 0, totalSteps: 0)
        XCTAssertEqual(progress.fraction, 0)
        XCTAssertEqual(progress.summary, "setup")
    }
}
