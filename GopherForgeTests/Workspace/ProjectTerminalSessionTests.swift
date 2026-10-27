import XCTest
@testable import GopherForge

@MainActor
final class ProjectTerminalSessionTests: XCTestCase {
    func testMissingJavaScriptRuntimesFailWithoutChangingTheGinProject() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "terminal-runtime-\(UUID().uuidString)", directoryHint: .isDirectory)
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: root.appending(path: "projects.json")))
        defer {
            workspace.siteServer.stop()
            try? FileManager.default.removeItem(at: root)
        }
        let project = GoExampleProjectGinCafe.cafe.project()
        XCTAssertTrue(workspace.open(project))
        let terminal = ProjectTerminalSession(workspace: workspace)

        for command in ["npm install", "npm run build", "npx vite", "bun install", "bun run build", "bunx vite", "node server.js"] {
            terminal.input = command
            await terminal.submit()
            let reply = try XCTUnwrap(terminal.transcript.last)
            guard case .failure = reply.kind else {
                return XCTFail("An unavailable runtime must be reported as a failure: \(command)")
            }
            XCTAssertTrue(reply.text.contains("is not installed in GopherForge"), command)
            XCTAssertTrue(reply.text.contains("external development environment"), command)
            XCTAssertNil(workspace.lastResult, "\(command) must not invoke the Go compiler")
            XCTAssertFalse(workspace.isRunning)
            XCTAssertFalse(terminal.isBusy)
            XCTAssertEqual(terminal.input, "")
            XCTAssertEqual(workspace.project?.files, project.files, "\(command) must not alter the project")
        }

        terminal.input = "cat go.mod"
        await terminal.submit()
        XCTAssertEqual(terminal.transcript.last?.text, project.files["go.mod"])
        await workspace.flush()
    }
}
