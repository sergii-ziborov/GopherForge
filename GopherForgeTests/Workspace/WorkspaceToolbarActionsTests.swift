import XCTest
@testable import GopherForge

final class WorkspaceToolbarActionsTests: XCTestCase {
    func testTheBarOffersRunBeautifyAndTestsOnly() {
        XCTAssertEqual(
            WorkspaceToolbarActions.primaryPhases,
            [.run, .format, .test]
        )
        XCTAssertFalse(WorkspaceToolbarActions.primaryPhases.contains(.build))
        XCTAssertEqual(GopherForgeTheme.label(for: .format), "Beautify")
        XCTAssertEqual(GopherForgeTheme.label(for: .run), "Run")
        XCTAssertEqual(GopherForgeTheme.label(for: .test), "Test")
    }

    func testCompileProgressOpensTheOutputPane() {
        XCTAssertEqual(WorkspacePane.afterStarting(.run), .output)
        XCTAssertEqual(WorkspacePane.afterStarting(.build), .output)
        XCTAssertEqual(WorkspacePane.afterStarting(.test), .tests)
        XCTAssertNil(WorkspacePane.afterStarting(.format))
    }

    func testALeadingEdgeSwipeOpensFiles() {
        XCTAssertTrue(FilesDrawerGesture.shouldOpen(startX: 8, translationWidth: 80))
        XCTAssertTrue(FilesDrawerGesture.shouldOpen(startX: 40, translationWidth: 80))
        XCTAssertFalse(FilesDrawerGesture.shouldOpen(startX: 120, translationWidth: 80))
        XCTAssertFalse(FilesDrawerGesture.shouldOpen(startX: 8, translationWidth: 10))
        XCTAssertFalse(
            FilesDrawerGesture.shouldOpen(
                startX: 8,
                translation: CGSize(width: 80, height: 200)
            ),
            "a vertical editor scroll must not open the drawer"
        )
        XCTAssertTrue(FilesDrawerGesture.shouldClose(translationWidth: -80))
        XCTAssertFalse(
            FilesDrawerGesture.shouldClose(translation: CGSize(width: -80, height: 200))
        )
        XCTAssertTrue(
            FilesDrawerGesture.shouldOpen(
                startX: 0,
                translation: CGSize(width: FilesDrawerGesture.minimumTranslation, height: 0)
            )
        )
        XCTAssertFalse(
            FilesDrawerGesture.shouldOpen(
                startX: FilesDrawerGesture.edgeWidth + 1,
                translationWidth: 200
            )
        )
    }

    func testEveryPrimaryPhaseOpensAUsefulPane() {
        XCTAssertEqual(WorkspacePane.afterStarting(.run), .output)
        XCTAssertEqual(WorkspacePane.afterStarting(.build), .output)
        XCTAssertEqual(WorkspacePane.afterStarting(.vet), .output)
        XCTAssertEqual(WorkspacePane.afterStarting(.setup), .output)
        XCTAssertEqual(WorkspacePane.afterStarting(.test), .tests)
        XCTAssertNil(WorkspacePane.afterStarting(.format))
    }

    func testAFailedCompileWithDiagnosticsGoesToProblems() {
        let diagnostic = GoDiagnostic(
            level: "error",
            message: "undefined: x",
            origin: .compiler,
            rendered: "main.go:1:1: undefined: x",
            span: nil,
            conceptTag: nil
        )
        let result = CompilationResult(
            succeeded: false,
            phase: .run,
            exitCode: 1,
            diagnostics: [diagnostic],
            stdout: "",
            stderr: "",
            duration: .zero,
            detail: "failed"
        )
        XCTAssertEqual(WorkspacePane.afterRun(result), .problems)
    }
}
