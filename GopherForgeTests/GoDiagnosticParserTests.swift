import XCTest
@testable import GopherForge

final class GoDiagnosticParserTests: XCTestCase {
    func testParsesLocationAndMessage() {
        let stderr = """
        # command-line-arguments
        ./main.go:6:2: declared and not used: host
        """
        let diagnostics = GoDiagnosticParser.parse(stderr: stderr)

        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].span?.fileName, "main.go")
        XCTAssertEqual(diagnostics[0].span?.line, 6)
        XCTAssertEqual(diagnostics[0].span?.column, 2)
        XCTAssertEqual(diagnostics[0].message, "declared and not used: host")
        XCTAssertEqual(diagnostics[0].conceptTag, GoConcept.varsUnused)
        XCTAssertTrue(diagnostics[0].isBlocking)
    }

    func testPackageBannerIsNotADiagnostic() {
        let diagnostics = GoDiagnosticParser.parse(stderr: "# example.com/forge/internal/build")
        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testIndentedNoteAttachesToPreviousDiagnostic() {
        let stderr = """
        ./main.go:9:6: x redeclared in this block
        \t./main.go:7:6: other declaration of x
        """
        let diagnostics = GoDiagnosticParser.parse(stderr: stderr)

        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertTrue(diagnostics[0].rendered.contains("other declaration of x"))
    }

    func testVetFindingsAreWarningsAndNeverBlock() {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: "./main.go:12:2: unreachable code",
            origin: .vet
        )
        XCTAssertEqual(diagnostics[0].level, "warning")
        XCTAssertFalse(diagnostics[0].isBlocking)
    }

    func testSourceLineIsAttachedWhenAvailable() {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: "./main.go:2:1: undefined: fmt",
            sourceLines: ["main.go": ["package main", "fmt.Println()"]]
        )
        XCTAssertEqual(diagnostics[0].span?.sourceLine, "fmt.Println()")
    }

    func testColumnlessLocationStillParses() {
        let diagnostics = GoDiagnosticParser.parse(stderr: "./main.go:4: missing return")
        XCTAssertEqual(diagnostics[0].span?.line, 4)
        XCTAssertEqual(diagnostics[0].span?.column, 0)
        XCTAssertEqual(diagnostics[0].conceptTag, GoConcept.missingReturn)
    }
}
