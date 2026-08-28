import XCTest
@testable import GopherForge

/// Where the workspace goes when a run finishes.
final class WorkspacePaneRoutingTests: XCTestCase {
    private func result(
        phase: CompilationResult.Phase,
        succeeded: Bool,
        diagnostics: [GoDiagnostic] = [],
        tests: [GoTestResult] = []
    ) -> CompilationResult {
        CompilationResult(
            succeeded: succeeded,
            phase: phase,
            exitCode: succeeded ? 0 : 1,
            diagnostics: diagnostics,
            stdout: "",
            stderr: "",
            duration: .milliseconds(1),
            detail: "",
            tests: tests
        )
    }

    private var diagnostic: GoDiagnostic {
        GoDiagnostic(
            level: "error",
            message: "undefined: fmt",
            origin: .compiler,
            rendered: "main.go:3:1: undefined: fmt",
            span: GoDiagnostic.Span(line: 3, column: 1),
            conceptTag: nil
        )
    }

    private var test: GoTestResult {
        GoTestResult(
            name: "TestThing",
            packagePath: "playground",
            outcome: .passed,
            elapsedSeconds: 0.01,
            output: ""
        )
    }

    func testAProgramThatRanShowsItsOutput() {
        XCTAssertEqual(
            WorkspacePane.afterRun(result(phase: .run, succeeded: true)),
            .output
        )
    }

    func testAFailedBuildShowsTheProblems() {
        XCTAssertEqual(
            WorkspacePane.afterRun(
                result(phase: .build, succeeded: false, diagnostics: [diagnostic])
            ),
            .problems
        )
    }

    func testATestRunShowsTheTests() {
        XCTAssertEqual(
            WorkspacePane.afterRun(result(phase: .test, succeeded: true, tests: [test])),
            .tests
        )
    }

    /// A failing test is still a test result. Sending the reader to Problems
    /// would hide the list that says which one failed.
    func testAFailingTestStillShowsTheTests() {
        XCTAssertEqual(
            WorkspacePane.afterRun(
                result(phase: .test, succeeded: false, diagnostics: [diagnostic], tests: [test])
            ),
            .tests
        )
    }

    /// A test build that never compiled has no tests to show, so the compiler
    /// errors are the answer.
    func testATestThatDidNotCompileShowsTheProblems() {
        XCTAssertEqual(
            WorkspacePane.afterRun(
                result(phase: .test, succeeded: false, diagnostics: [diagnostic])
            ),
            .problems
        )
    }

    /// Formatting rewrites the code on screen, so the code is the result and
    /// switching away from it would hide what just changed.
    func testASuccessfulFormatStaysOnTheCode() {
        XCTAssertNil(WorkspacePane.afterRun(result(phase: .format, succeeded: true)))
    }

    func testVetWithNothingToSayShowsTheOutput() {
        XCTAssertEqual(
            WorkspacePane.afterRun(result(phase: .vet, succeeded: true)),
            .output
        )
    }

    func testVetWithFindingsShowsTheProblems() {
        XCTAssertEqual(
            WorkspacePane.afterRun(
                result(phase: .vet, succeeded: true, diagnostics: [diagnostic])
            ),
            .problems
        )
    }

    /// Nothing routes to the code pane: the iPad dock cannot show it, and on
    /// iPhone the reader was already there.
    func testNothingEverRoutesToTheCodePane() {
        for phase in [CompilationResult.Phase.build, .run, .test, .vet, .format] {
            for succeeded in [true, false] {
                let destination = WorkspacePane.afterRun(
                    result(phase: phase, succeeded: succeeded)
                )
                XCTAssertNotEqual(destination, .code, "\(phase) succeeded=\(succeeded)")
            }
        }
    }
}
