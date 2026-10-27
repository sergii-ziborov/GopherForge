import XCTest
@testable import GopherForge

@MainActor
final class ProjectTerminalSessionTests: XCTestCase {
    func testOfflineFrontendCommandsBuildPersistAndInvalidatePreview() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "frontend-terminal-\(UUID().uuidString)", directoryHint: .isDirectory)
        let storage = root.appending(path: "projects.json")
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: storage))
        defer {
            workspace.siteServer.stop()
            try? FileManager.default.removeItem(at: root)
        }
        XCTAssertTrue(workspace.open(GoExampleProjectReactStudy.board.project()))
        workspace.select(file: "web/src/main.tsx")
        workspace.replaceEditorText(workspace.editorText + "\ndocument.documentElement.dataset.buildProof = 'latest-buffer';")
        let terminal = ProjectTerminalSession(workspace: workspace)
        terminal.input = "npm ci --offline"
        await terminal.submit()
        guard case .failure = terminal.transcript.last?.kind else { return XCTFail("ci must require a lock") }

        for command in ["npm install --offline", "npm ci --offline", "npm run build", "npm run preview"] {
            terminal.input = command
            await terminal.submit()
            let reply = try XCTUnwrap(terminal.transcript.last)
            if case .failure = reply.kind { return XCTFail("\(command): \(reply.text)") }
            XCTAssertFalse(terminal.isBusy)
        }
        XCTAssertEqual(workspace.sitePreviewURL?.scheme, OfflinePreviewResources.scheme)
        XCTAssertFalse(workspace.siteServer.isListening, "offline mode must not open a TCP listener")
        XCTAssertNil(workspace.lastResult, "frontend commands must not fabricate a Go run")
        let builtFiles = try XCTUnwrap(workspace.project?.files)
        XCTAssertTrue(builtFiles["web/dist/assets/app.js"]?.contains("latest-buffer") == true, "the current editor buffer must be built and preserved")
        XCTAssertTrue(OfflineFrontendPlan.previewReady(files: builtFiles))
        await workspace.flush()
        let saved = ProjectLibrary(storageURL: storage)
        let savedItems = try await saved.items()
        XCTAssertEqual(savedItems.first?.project.files, builtFiles)

        var broken = builtFiles
        broken["web/src/main.tsx"] = "import fs from 'node:fs'; fs.readFileSync('/private/host-file');"
        workspace.replaceFiles(with: broken)
        XCTAssertNil(workspace.sitePreviewURL)
        terminal.input = "npm run build"
        await terminal.submit()
        guard case .failure = terminal.transcript.last?.kind else { return XCTFail("Node built-ins must not be supplied") }
        XCTAssertTrue(terminal.transcript.last?.text.contains("node:fs") == true)
        XCTAssertEqual(workspace.project?.files, broken, "failed builds must not replace any files")
        XCTAssertNil(workspace.sitePreviewURL)
        await workspace.flush()
    }

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

        for command in ["npm exec vite", "npx vite", "bun install", "bun install --offline", "bun install --frozen-lockfile", "bun run build", "bun run preview", "bun --version", "bun run server", "bunx vite", "node server.js"] {
            terminal.input = command
            await terminal.submit()
            let reply = try XCTUnwrap(terminal.transcript.last)
            guard case .failure = reply.kind else {
                return XCTFail("An unavailable runtime must be reported as a failure: \(command)")
            }
            XCTAssertTrue(reply.text.contains("is not installed in GopherForge"), command)
            XCTAssertTrue(reply.text.contains("educational"), command)
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
