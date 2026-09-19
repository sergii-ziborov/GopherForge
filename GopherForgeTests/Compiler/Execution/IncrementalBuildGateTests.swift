import XCTest
@testable import GopherForge

/// The incremental build, proved by running one.
///
/// A cache that skips work is only safe if it also notices when it must not.
/// Both halves are asserted here: that unchanged packages really are reused,
/// and — the one that matters — that a changed dependency really does produce
/// new behaviour rather than replaying a stale archive.
final class IncrementalBuildGateTests: XCTestCase {
    private var compiler: WasmGoCompiler!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GOPHERFORGE_RUN_COMPILER_GATE"] == "1",
            "Run the GopherForgeCompilerGate scheme to execute the bundled-toolchain gates."
        )
        compiler = WasmGoCompiler()
        compiler.clearBuildCache()
    }

    /// Editing one file should recompile one package.
    ///
    /// Without this the whole graph is rebuilt on every keystroke-to-Build
    /// cycle, which is tolerable on a laptop and not on a phone, where one
    /// installed dependency can be a dozen packages that will never change.
    func testEditingOneFileRecompilesOnlyThatPackage() async throws {
        let greet = "package greet\n\nfunc Message() string { return \"hi\" }\n"
        func project(_ main: String) -> GoSourceSnapshot {
            GoSourceSnapshot(
                files: [
                    "go.mod": GoLanguage.module("example.com/forge"),
                    "main.go": main,
                    "a/a.go": "package a\n\nfunc A() string { return \"a\" }\n",
                    "greet/greet.go": greet,
                ],
                packagePattern: ".",
                entryFile: "main.go"
            )
        }
        let main = """
        package main

        import (
        \t"fmt"

        \t"example.com/forge/a"
        \t"example.com/forge/greet"
        )

        func main() { fmt.Println(greet.Message(), a.A()) }
        """

        let first = await compiler.build(project: project(main))
        XCTAssertTrue(first.succeeded, report(first))
        XCTAssertEqual(first.reusedSteps, 0, "a cold build has nothing to reuse")

        // Only main.go changes; the two dependencies are byte-identical.
        let second = await compiler.build(project: project(main + "\n// touched\n"))

        XCTAssertTrue(second.succeeded, report(second))
        XCTAssertEqual(
            second.reusedSteps, 2,
            "both unchanged packages should have been reused, got \(second.reusedSteps)"
        )
        XCTAssertTrue(second.detail.contains("reused"), second.detail)
    }

    /// The safety property the cache rests on: changing a dependency must
    /// invalidate everything that depends on it, not just itself.
    func testChangingADependencyRebuildsWhatImportsIt() async throws {
        func project(_ greet: String) -> GoSourceSnapshot {
            GoSourceSnapshot(
                files: [
                    "go.mod": GoLanguage.module("example.com/forge"),
                    "main.go": "package main\n\nimport (\n\t\"fmt\"\n\n"
                        + "\t\"example.com/forge/greet\"\n)\n\n"
                        + "func main() { fmt.Println(greet.Message()) }\n",
                    "greet/greet.go": greet,
                ],
                packagePattern: ".",
                entryFile: "main.go"
            )
        }

        let first = await compiler.run(project: project("package greet\n\nfunc Message() string { return \"one\" }\n"))
        XCTAssertTrue(first.succeeded, report(first))
        XCTAssertTrue(first.stdout.contains("one"), report(first))

        let second = await compiler.run(project: project("package greet\n\nfunc Message() string { return \"two\" }\n"))

        XCTAssertTrue(second.succeeded, report(second))
        XCTAssertTrue(
            second.stdout.contains("two"),
            "a stale archive would still print 'one': \(report(second))"
        )
    }


    private func report(_ result: CompilationResult) -> String {
        """
        \(result.detail)
        stdout: \(result.stdout)
        stderr: \(result.stderr)
        diagnostics: \(result.diagnostics.map(\.message))
        """
    }
}
