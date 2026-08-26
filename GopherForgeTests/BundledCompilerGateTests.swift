import XCTest
@testable import GopherForge

/// The gates that need the real bundled toolchain.
///
/// They are excluded from the normal test scheme because each one runs a full
/// Go build inside an interpreter. The dedicated `GopherForgeCompilerGate`
/// scheme runs exactly these, with `GOPHERFORGE_RUN_COMPILER_GATE=1`.
///
/// A missing toolchain fails these tests rather than skipping them: "we could
/// not check" and "it works" must never look the same.
final class BundledCompilerGateTests: XCTestCase {
    private var compiler: WasmGoCompiler!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GOPHERFORGE_RUN_COMPILER_GATE"] == "1",
            "Run the GopherForgeCompilerGate scheme to execute the bundled-toolchain gates."
        )
        compiler = WasmGoCompiler()
    }

    func testBundledGoReportsUnusedVariable() async throws {
        let snapshot = GoSourceSnapshot.singleFile("""
        package main

        import "fmt"

        func main() {
        \thost := "localhost"
        \tfmt.Println("started")
        }
        """)

        let result = await compiler.build(project: snapshot)

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.diagnostics.contains { $0.conceptTag == GoConcept.varsUnused },
            "expected a declared-and-not-used diagnostic, got: \(result.diagnostics.map(\.message))"
        )
    }

    func testBundledGoCompilesAndRunsRepairedProgram() async throws {
        let snapshot = GoSourceSnapshot.singleFile("""
        package main

        import "fmt"

        func main() {
        \tfmt.Println("forge")
        }
        """)

        let result = await compiler.run(project: snapshot)

        XCTAssertTrue(result.succeeded, result.detail)
        XCTAssertTrue(result.stdout.contains("forge"))
    }

    func testBundledGoCompilesMultiPackageProject() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": "module example.com/forge\n\ngo 1.27\n",
                "main.go": """
                package main

                import (
                \t"fmt"

                \t"example.com/forge/internal/greet"
                )

                func main() {
                \tfmt.Println(greet.Message("gopher"))
                }
                """,
                "internal/greet/greet.go": """
                package greet

                // Message returns the greeting for name.
                func Message(name string) string {
                \treturn "hello, " + name
                }
                """,
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let result = await compiler.run(project: snapshot)

        XCTAssertTrue(result.succeeded, result.detail)
        XCTAssertTrue(result.stdout.contains("hello, gopher"))
    }

    func testBundledGoRunsPackageTests() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": "module example.com/forge\n\ngo 1.27\n",
                "reverse.go": """
                package main

                func Reverse(s string) string {
                \trunes := []rune(s)
                \tfor i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
                \t\trunes[i], runes[j] = runes[j], runes[i]
                \t}
                \treturn string(runes)
                }

                func main() {}
                """,
                "reverse_test.go": """
                package main

                import "testing"

                func TestReverse(t *testing.T) {
                \tif Reverse("go") != "og" {
                \t\tt.Fatal("wrong")
                \t}
                }
                """,
            ],
            packagePattern: ".",
            entryFile: "reverse.go"
        )

        let result = await compiler.test(project: snapshot)

        XCTAssertTrue(result.succeeded, result.detail)
        XCTAssertTrue(result.tests.allPassed)
    }

    func testBundledGoSurvivesRepeatedBuilds() async throws {
        let snapshot = GoSourceSnapshot.singleFile("""
        package main

        func main() { println("cycle") }
        """)

        for cycle in 1...3 {
            let result = await compiler.run(project: snapshot)
            XCTAssertTrue(result.succeeded, "cycle \(cycle): \(result.detail)")
        }
    }

    func testUserProgramCannotGrowPastSandboxMemoryLimit() async throws {
        let snapshot = GoSourceSnapshot.singleFile("""
        package main

        func main() {
        \tblocks := make([][]byte, 0, 128)
        \tfor i := 0; i < 128; i++ {
        \t\tblocks = append(blocks, make([]byte, 1<<20))
        \t}
        \tprintln(len(blocks))
        }
        """)

        let result = await compiler.run(project: snapshot)

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.detail.contains("sandbox memory limit"),
            "expected the sandbox to stop the allocation, got: \(result.detail)"
        )
    }
}
