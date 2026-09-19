import XCTest
@testable import GopherForge

final class GoTestFunctionScannerMoreTests: XCTestCase {
    func testIndentedFunctionsAreNotEntryPoints() {
        let functions = GoTestFunctionScanner.scan(
            source: """
            package p
            func wrapper() {
                func TestHidden(t *testing.T) {}
            }
            """,
            isExternal: false
        )
        XCTAssertFalse(functions.contains { $0.name == "TestHidden" })
    }

    func testTestMainIsMarkedCustom() {
        let functions = GoTestFunctionScanner.scan(
            source: "package p\nfunc TestMain(m *testing.M) {}\nfunc TestReal(t *testing.T) {}\n",
            isExternal: false
        )
        XCTAssertTrue(functions.first { $0.name == "TestMain" }?.isCustomMain == true)
        XCTAssertFalse(functions.first { $0.name == "TestReal" }?.isCustomMain == true)
    }

    func testExternalFlagIsPreserved() {
        let functions = GoTestFunctionScanner.scan(
            source: "package p_test\nfunc TestOut(t *testing.T) {}\n",
            isExternal: true
        )
        XCTAssertTrue(functions.first?.isExternal == true)
    }

    func testExampleOutputWithNoSpaceAfterSlashes() {
        let functions = GoTestFunctionScanner.scan(
            source: """
            package p
            func ExampleX() {
            //output: 7
            }
            """,
            isExternal: false
        )
        XCTAssertEqual(functions.first?.expectedOutput, "7\n")
    }

    func testAMultilineExampleOutput() {
        let functions = GoTestFunctionScanner.scan(
            source: """
            package p
            func ExampleX() {
            \t// Output:
            \t// hello
            \t// world
            }
            """,
            isExternal: false
        )
        XCTAssertEqual(functions.first?.expectedOutput, "hello\nworld\n")
    }
}
