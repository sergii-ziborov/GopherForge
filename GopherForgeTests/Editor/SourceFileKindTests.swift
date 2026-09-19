import XCTest
@testable import GopherForge

final class SourceFileKindTests: XCTestCase {
    func testKindsFollowTheFileName() {
        XCTAssertEqual(SourceFileKind.of(path: "main.go"), .go)
        XCTAssertEqual(SourceFileKind.of(path: "cmd/tool/main.go"), .go)
        XCTAssertEqual(SourceFileKind.of(path: "go.mod"), .goMod)
        XCTAssertEqual(SourceFileKind.of(path: "nested/go.mod"), .goMod)
        XCTAssertEqual(SourceFileKind.of(path: "go.sum"), .goSum)
        XCTAssertEqual(SourceFileKind.of(path: "README.md"), .markdown)
        XCTAssertEqual(SourceFileKind.of(path: "notes.txt"), .plain)
    }

    func testGoAndGoModProduceTokensAndTheRestDoNot() {
        XCTAssertFalse(SourceFileKind.go.tokens(in: "package main\n").isEmpty)
        XCTAssertFalse(SourceFileKind.goMod.tokens(in: "module playground\n").isEmpty)
        XCTAssertTrue(SourceFileKind.goSum.tokens(in: "x").isEmpty)
        XCTAssertTrue(SourceFileKind.markdown.tokens(in: "# hi").isEmpty)
        XCTAssertTrue(SourceFileKind.plain.tokens(in: "plain").isEmpty)
    }

    func testEveryKindHasAnIcon() {
        for kind in SourceFileKind.allCases {
            XCTAssertFalse(kind.systemImage.isEmpty)
            XCTAssertFalse(kind.isTestFile)
        }
    }
}
