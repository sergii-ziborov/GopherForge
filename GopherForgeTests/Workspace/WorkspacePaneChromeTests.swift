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
