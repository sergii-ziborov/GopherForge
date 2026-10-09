import XCTest
@testable import GopherForge

final class WorkspacePaneChromeTests: XCTestCase {
    func testEveryPaneHasATitleAndADistinctSymbol() {
        XCTAssertEqual(WorkspacePane.allCases.count, 6)
        let symbols = Set(WorkspacePane.allCases.map(\.systemImage))
        XCTAssertEqual(symbols.count, WorkspacePane.allCases.count)
        for pane in WorkspacePane.allCases {
            XCTAssertFalse(pane.title.isEmpty)
            XCTAssertEqual(pane.id, pane.rawValue)
        }
    }

    func testTheDockOmitsTheEditor() {
        XCTAssertEqual(WorkspacePane.dockPanes, [.problems, .output, .tests, .idioms, .terminal])
        XCTAssertFalse(WorkspacePane.dockPanes.contains(.code))
        XCTAssertEqual(Set(WorkspacePane.workPanes), Set(WorkspacePane.allCases))
        XCTAssertEqual(Array(WorkspacePane.workPanes.prefix(2)), [.code, .terminal])
    }

    func testWorkspaceGainsColumnsAsTheWindowUnfolds() {
        XCTAssertEqual(WorkspaceLayout.resolve(width: 466, isPad: false), .compact)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 669, isPad: false), .columns)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 899, isPad: false), .columns)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 900, isPad: false), .canvas)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 1100, isPad: false), .canvas)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 820, isPad: true), .tablet)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 500, isPad: true), .compact)
        XCTAssertTrue(WorkspaceLayout.canvas.showsDock)
        XCTAssertFalse(WorkspaceLayout.columns.showsDock)
        XCTAssertGreaterThanOrEqual(1100 - WorkspaceLayout.navigatorWidth(for: 1100)
            - WorkspaceLayout.inspectorWidth(for: 1100), 400)
    }

    func testPhaseLabelsMatchTheToolbar() {
        XCTAssertEqual(GopherForgeTheme.label(for: .format), "Beautify")
        XCTAssertEqual(GopherForgeTheme.label(for: .vet), "Vet")
        XCTAssertEqual(GopherForgeTheme.label(for: .build), "Build")
        XCTAssertEqual(GopherForgeTheme.label(for: .run), "Run")
        XCTAssertEqual(GopherForgeTheme.label(for: .test), "Test")
        XCTAssertEqual(GopherForgeTheme.label(for: .setup), "Setup")
        for phase in [CompilationResult.Phase.format, .vet, .build, .run, .test, .setup] {
            XCTAssertFalse(GopherForgeTheme.systemImage(for: phase).isEmpty)
        }
    }
}
