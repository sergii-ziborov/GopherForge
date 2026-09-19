import XCTest
@testable import GopherForge

final class GoTestOutputParserMoreTests: XCTestCase {
    func testASkippedCase() {
        let results = GoTestOutputParser.parse(
            stdout: """
            === RUN   TestSkip
            --- SKIP: TestSkip (0.00s)
            """
        )
        XCTAssertEqual(results.first?.outcome, .skipped)
    }

    func testAnEmptyStreamIsNoTests() {
        XCTAssertTrue(GoTestOutputParser.parse(stdout: "").isEmpty)
        XCTAssertTrue(GoTestOutputParser.parse(stdout: "ok  \texample.com/forge\t0.01s\n").isEmpty)
    }

    func testAPackageBannerIsAttachedToFollowingCases() {
        let results = GoTestOutputParser.parse(
            stdout: """
            ok  \texample.com/forge/mathx
            === RUN   TestAdd
            --- PASS: TestAdd (0.00s)
            """
        )
        XCTAssertEqual(results.first?.name, "TestAdd")
        XCTAssertEqual(results.first?.outcome, .passed)
        XCTAssertEqual(results.first?.packagePath, "example.com/forge/mathx")
    }
}
