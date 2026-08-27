import XCTest
@testable import GopherForge

/// The generated `_testmain.go`.
///
/// `go test` writes this file too, for the same reason: `testing` needs a table
/// of entry points and Go has no runtime discovery to build one. If this file
/// is wrong the failure is a compile error inside generated code the user never
/// wrote, so its shape is worth asserting directly.
final class GoTestMainGeneratorTests: XCTestCase {
    func testFindsEveryKindOfEntryPoint() {
        let functions = GoTestFunctionScanner.scan(
            source: """
            package mathx

            import "testing"

            func TestDouble(t *testing.T) {}
            func BenchmarkDouble(b *testing.B) {}
            func FuzzDouble(f *testing.F) {}
            func ExampleDouble() {}

            func helper(t *testing.T) {}
            func TestingIsNotATest() {}
            """,
            isExternal: false
        )

        XCTAssertEqual(
            functions.map(\.name),
            ["TestDouble", "BenchmarkDouble", "FuzzDouble", "ExampleDouble"]
        )
        XCTAssertEqual(functions.map(\.kind), [.test, .benchmark, .fuzz, .example])
    }

    func testReadsAnExamplesExpectedOutput() {
        let functions = GoTestFunctionScanner.scan(
            source: """
            package mathx

            func ExampleDouble() {
            \tfmt.Println(Double(2))
            \t// Output:
            \t// 4
            }
            """,
            isExternal: false
        )

        XCTAssertEqual(functions.first?.expectedOutput, "4\n")
    }

    /// An example with no output comment is compiled but not run, which is what
    /// `go test` does. An empty `Output` is exactly how `testing` expresses it.
    func testAnExampleWithoutAnOutputCommentIsNotRun() {
        let functions = GoTestFunctionScanner.scan(
            source: "package mathx\n\nfunc ExampleDouble() {\n\t_ = Double(2)\n}\n",
            isExternal: false
        )

        XCTAssertEqual(functions.first?.expectedOutput, "")
    }

    func testGeneratesATableAndAnEntryPoint() {
        let source = GoTestMainGenerator.source(
            importPath: "example.com/forge/mathx",
            functions: [
                GoTestFunction(kind: .test, name: "TestDouble", isExternal: false, expectedOutput: ""),
            ],
            hasExternalPackage: false
        )

        XCTAssertTrue(source.contains("_test \"example.com/forge/mathx\""))
        XCTAssertTrue(source.contains("{Name: \"TestDouble\", F: _test.TestDouble},"))
        XCTAssertTrue(source.contains("testdeps.ImportPath = \"example.com/forge/mathx\""))
        XCTAssertTrue(source.contains("os.Exit(m.Run())"))
        XCTAssertFalse(source.contains("_xtest"), "nothing external here, so no external import")
        XCTAssertFalse(source.contains("\"reflect\""), "reflect is only for a custom TestMain")
    }

    func testImportsTheExternalPackageWhenOneExists() {
        let source = GoTestMainGenerator.source(
            importPath: "example.com/forge/mathx",
            functions: [
                GoTestFunction(kind: .test, name: "TestInside", isExternal: false, expectedOutput: ""),
                GoTestFunction(kind: .test, name: "TestOutside", isExternal: true, expectedOutput: ""),
            ],
            hasExternalPackage: true
        )

        XCTAssertTrue(source.contains("_xtest \"example.com/forge/mathx_test\""))
        XCTAssertTrue(source.contains("F: _test.TestInside"))
        XCTAssertTrue(source.contains("F: _xtest.TestOutside"))
    }

    /// `TestMain` is not a test; it replaces the entry point, and the exit code
    /// then has to be read back the way upstream reads it.
    func testACustomTestMainTakesOverTheEntryPoint() {
        let source = GoTestMainGenerator.source(
            importPath: "example.com/forge",
            functions: [
                GoTestFunction(kind: .test, name: "TestMain", isExternal: false, expectedOutput: ""),
                GoTestFunction(kind: .test, name: "TestReal", isExternal: false, expectedOutput: ""),
            ],
            hasExternalPackage: false
        )

        XCTAssertTrue(source.contains("_test.TestMain(m)"))
        XCTAssertTrue(source.contains("\"reflect\""))
        XCTAssertFalse(source.contains("os.Exit(m.Run())"))
        XCTAssertFalse(
            source.contains("F: _test.TestMain"),
            "TestMain must not also appear in the table it controls"
        )
        XCTAssertTrue(source.contains("F: _test.TestReal"))
    }

    func testEmptyTablesAreStillDeclared() {
        let source = GoTestMainGenerator.source(
            importPath: "example.com/forge",
            functions: [
                GoTestFunction(kind: .test, name: "TestOnly", isExternal: false, expectedOutput: ""),
            ],
            hasExternalPackage: false
        )

        for table in ["benchmarks", "fuzzTargets", "examples"] {
            XCTAssertTrue(
                source.contains("var \(table) = []testing.Internal"),
                "\(table) must exist even when empty: MainStart takes all four"
            )
        }
    }
}
