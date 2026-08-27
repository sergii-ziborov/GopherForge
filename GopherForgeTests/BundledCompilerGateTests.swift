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

    /// The first device build was reported as "nothing compiles". It was
    /// compiling; nothing on screen said so. This asserts the app has something
    /// to say while it works.
    func testABuildReportsEveryStepItTakes() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": GoLanguage.module("example.com/forge"),
                "main.go": "package main\n\nimport (\n\t\"fmt\"\n\n\t\"example.com/forge/greet\"\n)\n\nfunc main() { fmt.Println(greet.Message()) }\n",
                "greet/greet.go": "package greet\n\nfunc Message() string { return \"hi\" }\n",
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let collected = ProgressCollector()
        let result = await compiler.build(project: snapshot) { collected.append($0) }
        XCTAssertTrue(result.succeeded, report(result))

        let progress = collected.reported
        XCTAssertGreaterThanOrEqual(progress.count, 3, "two packages and a link is three steps")
        XCTAssertEqual(progress.map(\.step), Array(1...progress.count), "steps should arrive in order")
        XCTAssertEqual(progress.last?.step, progress.last?.totalSteps, "the last step should finish the plan")
        XCTAssertTrue(
            progress.contains { $0.label.contains("example.com/forge/greet") },
            "a step should name the package it is compiling, got: \(progress.map(\.label))"
        )
        XCTAssertEqual(progress.first?.fraction ?? 0, 1.0 / Double(progress.count), accuracy: 0.001)
    }

    /// The handler is called from the compiler's own queue, so collecting has
    /// to be safe from there rather than only from the test's actor.
    private final class ProgressCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [GoBuildProgress] = []

        var reported: [GoBuildProgress] { lock.withLock { storage } }

        func append(_ progress: GoBuildProgress) {
            lock.withLock { storage.append(progress) }
        }
    }

    /// Every example in the library, compiled and run.
    ///
    /// "Working examples" is a claim, and this is what makes it a checked one.
    /// An example that stops compiling, or that quietly starts printing
    /// something else, fails here rather than teaching someone the wrong thing.
    func testEveryExampleCompilesAndPrintsWhatItClaims() async throws {
        XCTAssertFalse(GoExampleLibrary.all.isEmpty, "the library should not be empty")

        var failures: [String] = []
        for example in GoExampleLibrary.all {
            let result = await compiler.run(project: example.snapshot())
            guard result.succeeded else {
                failures.append("\(example.id): did not run — \(report(result))")
                continue
            }
            if result.stdout != example.expectedOutput {
                failures.append(
                    """
                    \(example.id): printed something else
                    expected: \(example.expectedOutput.debugDescription)
                    actual:   \(result.stdout.debugDescription)
                    """
                )
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n\n"))
    }

    /// Identifiers are how an example is referred to from a concept or a
    /// review item, so two examples sharing one is a silent redirect.
    func testExampleIdentifiersAreUnique() {
        let ids = GoExampleLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate example ids in \(ids)")
    }

    /// A vendored dependency, compiled by the real toolchain.
    ///
    /// This is the half of package installation that has nothing to do with the
    /// network: once a module's source is under `vendor/`, the build has to
    /// find it under its published import path rather than under this module's.
    /// No download happens here — the vendored package is written by hand,
    /// which is exactly what makes this a test of the build and not of a proxy.
    func testAVendoredPackageIsCompiledUnderItsPublishedImportPath() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": "module playground\n\ngo 1.24\n\nrequire (\n\texample.com/greet v1.2.0\n)\n",
                "main.go": "package main\n\nimport (\n\t\"fmt\"\n\n\t\"example.com/greet\"\n)\n\n"
                    + "func main() { fmt.Println(greet.Message(\"gopher\")) }\n",
                "vendor/example.com/greet/greet.go":
                    "package greet\n\nfunc Message(name string) string { return \"hello, \" + name }\n",
                "vendor/modules.txt": "# example.com/greet v1.2.0\n## explicit\nexample.com/greet\n",
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let result = await compiler.run(project: snapshot)

        XCTAssertTrue(result.succeeded, report(result))
        XCTAssertTrue(result.stdout.contains("hello, gopher"), report(result))
    }

    /// The offline promise, stated as a test: an import that is neither in the
    /// module, nor vendored, nor in the bundled standard library is refused
    /// before any tool runs — with a sentence rather than a linker error.
    func testAnUninstalledImportIsRefusedWithSomethingReadable() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": "module playground\n\ngo 1.24\n",
                "main.go": "package main\n\nimport \"github.com/google/uuid\"\n\n"
                    + "func main() { _ = uuid.New() }\n",
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let result = await compiler.build(project: snapshot)

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.detail.contains("github.com/google/uuid"),
            "the message should name the import, got: \(result.detail)"
        )
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
