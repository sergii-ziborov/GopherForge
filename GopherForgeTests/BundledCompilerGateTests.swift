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
        // Cold, every time. A cached artifact makes a build that never happened
        // look exactly like one that did, and these are the tests that must be
        // able to tell those apart.
        compiler.clearBuildCache()
    }

    /// A generated `go.mod` is a promise about which language rules apply, and
    /// a module asking for a version the bundled compiler does not have is
    /// refused outright. This is the assertion that stops the two drifting.
    func testGeneratedModulesNeverAskForMoreGoThanIsBundled() throws {
        let bundled = compiler.probe()
        XCTAssertTrue(bundled.isReady, "this gate needs a staged toolchain")

        let declared = try XCTUnwrap(Self.majorMinor(of: GoLanguage.declaredModuleVersion))
        let available = try XCTUnwrap(Self.majorMinor(of: bundled.goVersion))

        XCTAssertFalse(
            available.lexicographicallyPrecedes(declared),
            "generated modules declare go \(GoLanguage.declaredModuleVersion) "
                + "but the bundle carries \(bundled.goVersion)"
        )
    }

    /// `go1.24.2` and `1.24` both reduce to `[1, 24]`, which is the only part
    /// a `go` line in a module can express.
    private static func majorMinor(of version: String) -> [Int]? {
        let numbers = version
            .drop(while: { !$0.isNumber })
            .split(separator: ".")
            .compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }
        return Array(numbers.prefix(2))
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
            "expected a declared-and-not-used diagnostic, got: \(report(result))"
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

        XCTAssertTrue(result.succeeded, report(result))
        XCTAssertTrue(result.stdout.contains("forge"), report(result))
    }

    func testBundledGoCompilesMultiPackageProject() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": GoLanguage.module("example.com/forge"),
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

        XCTAssertTrue(result.succeeded, report(result))
        XCTAssertTrue(result.stdout.contains("hello, gopher"), report(result))
    }

    func testBundledGoRunsPackageTests() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": GoLanguage.module("example.com/forge"),
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

        XCTAssertTrue(result.succeeded, report(result))
        XCTAssertTrue(result.tests.allPassed, report(result))
    }

    func testBundledGoSurvivesRepeatedBuilds() async throws {
        let snapshot = GoSourceSnapshot.singleFile("""
        package main

        func main() { println("cycle") }
        """)

        for cycle in 1...3 {
            let result = await compiler.run(project: snapshot)
            XCTAssertTrue(result.succeeded, "cycle \(cycle): \(report(result))")
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
        // Two shapes, both correct. Either the limiter refuses the growth and
        // the app names the limit, or Go's own allocator sees the refusal first
        // and reports running out of memory. What must never happen is the
        // program getting the 128 MB it asked for.
        let stoppedBySandbox = result.detail.contains("sandbox memory limit")
        let stoppedByGuest = result.stderr.contains("out of memory")
        XCTAssertTrue(
            stoppedBySandbox || stoppedByGuest,
            "expected the sandbox to stop the allocation, got: \(report(result))"
        )
        if let inUse = bytesInUse(reportedIn: result.stderr) {
            XCTAssertLessThanOrEqual(
                inUse,
                WasmSandboxPolicy.userProgramMemoryLimitBytes,
                "the program should have been stopped at the limit, not above it"
            )
        }
    }

    /// Go reports `(62750720 in use)` when it runs out; reading that back is
    /// what turns "the program failed" into "the limit is what stopped it".
    private func bytesInUse(reportedIn stderr: String) -> Int? {
        guard let match = stderr.firstMatch(of: /\((?<bytes>\d+) in use\)/) else { return nil }
        return Int(match.output.bytes)
    }

    /// A gate that fails has to say why. Without the toolchain's own output a
    /// failure here reads as "the build failed", which is the one thing nobody
    /// can act on.
    private func report(_ result: CompilationResult) -> String {
        """
        \(result.detail)
        stdout: \(result.stdout)
        stderr: \(result.stderr)
        diagnostics: \(result.diagnostics.map(\.message))
        """
    }
}
