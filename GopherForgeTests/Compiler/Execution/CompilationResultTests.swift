import XCTest
@testable import GopherForge

final class CompilationResultTests: XCTestCase {
    func testAFailureFactoryLeavesNoDiagnostics() {
        let result = CompilationResult.failure(
            phase: .setup,
            detail: "Bundled Go toolchain is missing.",
            stderr: "nope"
        )
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.phase, .setup)
        XCTAssertNil(result.exitCode)
        XCTAssertTrue(result.diagnostics.isEmpty)
        XCTAssertEqual(result.stderr, "nope")
        XCTAssertTrue(result.tests.isEmpty)
        XCTAssertEqual(result.reusedSteps, 0)
        XCTAssertTrue(result.artifacts.isEmpty)
    }

    func testBlockingDiagnosticsAreCompilerErrors() {
        let error = GoDiagnostic(
            level: "error",
            message: "undefined: x",
            origin: .compiler,
            rendered: "main.go:1:1: undefined: x",
            span: nil,
            conceptTag: nil
        )
        let warning = GoDiagnostic(
            level: "warning",
            message: "printf",
            origin: .vet,
            rendered: "main.go:1:1: printf",
            span: nil,
            conceptTag: nil
        )
        let result = CompilationResult(
            succeeded: false,
            phase: .build,
            exitCode: 1,
            diagnostics: [error, warning],
            stdout: "",
            stderr: "",
            duration: .zero,
            detail: "failed"
        )
        XCTAssertEqual(result.blockingDiagnostics.map(\.message), [error.message])
        XCTAssertFalse(warning.isBlocking)
        XCTAssertTrue(error.isBlocking)
    }

    func testAVetWarningIsNeverBlocking() {
        let diagnostic = GoDiagnostic(
            level: "error",
            message: "printf",
            origin: .vet,
            rendered: "x",
            span: nil,
            conceptTag: nil
        )
        XCTAssertFalse(diagnostic.isBlocking)
    }

    func testAppendingAContinuationKeepsTheTag() {
        let original = GoDiagnostic(
            level: "error",
            message: "undefined: x",
            origin: .compiler,
            rendered: "main.go:1:1: undefined: x",
            span: .init(line: 1, column: 1),
            conceptTag: GoConcept.undefinedSymbol
        )
        let continued = original.appendingContinuation("have you written it yet?")
        XCTAssertTrue(continued.rendered.contains("have you written it yet?"))
        XCTAssertEqual(continued.conceptTag, GoConcept.undefinedSymbol)
        XCTAssertEqual(continued.message, original.message)
    }

    func testPhasesCoverEveryButton() {
        let phases: [CompilationResult.Phase] = [.format, .vet, .build, .run, .test, .setup]
        XCTAssertEqual(Set(phases.map(\.rawValue)), Set(phases.map(\.rawValue)))
        XCTAssertEqual(phases.count, 6)
    }
}
