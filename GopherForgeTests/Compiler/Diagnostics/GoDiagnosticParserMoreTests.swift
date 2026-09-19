import XCTest
@testable import GopherForge

final class GoDiagnosticParserMoreTests: XCTestCase {
    func testAWorkPrefixedPathIsProjectRelative() {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: "/tmp/job/work/internal/greet/greet.go:3:1: undefined: X"
        )
        XCTAssertEqual(diagnostics.first?.span?.fileName, "internal/greet/greet.go")
    }

    func testUnparseableLinesAreIgnored() {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: "this is not a diagnostic\n# banner\n"
        )
        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testAFourSpaceContinuationAttaches() {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: """
            ./main.go:1:1: cannot use x
                as type string
            """
        )
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertTrue(diagnostics[0].rendered.contains("as type string"))
    }

    func testTwoFindingsStaySeparate() {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: """
            ./a.go:1:1: undefined: A
            ./b.go:2:1: undefined: B
            """
        )
        XCTAssertEqual(diagnostics.map(\.message), ["undefined: A", "undefined: B"])
        XCTAssertEqual(diagnostics.map(\.conceptTag), [GoConcept.undefinedSymbol, GoConcept.undefinedSymbol])
    }
}
