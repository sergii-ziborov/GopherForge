import XCTest
@testable import GopherForge

final class GoPlanFailureReaderTests: XCTestCase {
    func testNoGoFiles() {
        let text = GoPlanFailureReader.describe(.noGoFiles)
        XCTAssertTrue(text.contains("no .go files"))
    }

    func testConflictingNamesAtTheRoot() {
        let text = GoPlanFailureReader.describe(
            .conflictingPackageNames(directory: "", names: ["main", "other"])
        )
        XCTAssertTrue(text.contains("The module root"))
        XCTAssertTrue(text.contains("main"))
        XCTAssertTrue(text.contains("other"))
    }

    func testConflictingNamesInADirectory() {
        let text = GoPlanFailureReader.describe(
            .conflictingPackageNames(directory: "internal/greet", names: ["greet", "hello"])
        )
        XCTAssertTrue(text.contains("internal/greet"))
        XCTAssertTrue(text.contains("package clause"))
    }

    func testAnImportCycleIsDrawnAsAPath() {
        let text = GoPlanFailureReader.describe(
            .importCycle(path: ["a", "b", "a"])
        )
        XCTAssertTrue(text.contains("a → b → a"))
        XCTAssertTrue(text.contains("circle"))
    }

    func testAnUnresolvedImportSaysTheAppIsOffline() {
        let text = GoPlanFailureReader.describe(
            .unresolvedImport("github.com/x/y", importedBy: "playground")
        )
        XCTAssertTrue(text.contains("playground"))
        XCTAssertTrue(text.contains("github.com/x/y"))
        XCTAssertTrue(text.contains("offline") || text.contains("bundled standard library"))
    }

    func testAmbiguousMainsAskTheReaderToChoose() {
        let text = GoPlanFailureReader.describe(
            .ambiguousMainPackages(["cmd/one", "cmd/two"])
        )
        XCTAssertTrue(text.contains("cmd/one"))
        XCTAssertTrue(text.contains("cmd/two"))
        XCTAssertTrue(text.contains("main.go"))
    }
}
