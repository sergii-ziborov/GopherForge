import XCTest
@testable import GopherForge

final class SourceFileLimitTests: XCTestCase {
    func testEmptyTextIsZeroLines() {
        XCTAssertEqual(SourceFileLimit.lineCount(of: ""), 0)
        XCTAssertFalse(SourceFileLimit.exceedsLimit(""))
    }

    func testASingleLineWithoutANewlineCountsAsOne() {
        XCTAssertEqual(SourceFileLimit.lineCount(of: "package main"), 1)
        XCTAssertEqual(SourceFileLimit.lineCount(of: "a\nb"), 2)
    }

    func testVendoredFilesAreNotOwnSources() {
        let long = (0...SourceFileLimit.maximumLines).map { "// \($0)" }.joined(separator: "\n")
        XCTAssertTrue(SourceFileLimit.exceedsLimit(long))
        XCTAssertEqual(
            SourceFileLimit.oversizedOwnFiles(in: [
                "main.go": "package main\n",
                "vendor/github.com/x/y/y.go": long,
                "big.go": long,
            ]),
            ["big.go"]
        )
    }
}
