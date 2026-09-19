import XCTest
@testable import GopherForge

final class GoTestOutputParserTests: XCTestCase {
    private let sample = """
    === RUN   TestReverse
    --- PASS: TestReverse (0.00s)
    === RUN   TestClamp
        clamp_test.go:18: Clamp(-3) = -3, want 0
    --- FAIL: TestClamp (0.01s)
    FAIL
    FAIL	example.com/forge	0.312s
    """

    func testParsesEachCase() {
        let results = GoTestOutputParser.parse(stdout: sample)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "TestReverse")
        XCTAssertEqual(results[0].outcome, .passed)
        XCTAssertEqual(results[1].outcome, .failed)
        XCTAssertEqual(results[1].elapsedSeconds, 0.01)
    }

    func testFailureOutputIsAttachedToItsCase() {
        let results = GoTestOutputParser.parse(stdout: sample)
        XCTAssertTrue(results[1].output.contains("want 0"))
        XCTAssertTrue(results[0].output.isEmpty)
    }

    func testCountsSummariseTheRun() {
        let results = GoTestOutputParser.parse(stdout: sample)
        XCTAssertEqual(results.passedCount, 1)
        XCTAssertEqual(results.failedCount, 1)
        XCTAssertFalse(results.allPassed)
    }
}
