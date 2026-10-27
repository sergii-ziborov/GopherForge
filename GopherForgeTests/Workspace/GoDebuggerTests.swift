import XCTest
@testable import GopherForge

@MainActor
final class GoDebuggerTests: XCTestCase {
    func testRunAutomaticallyChoosesDebuggingAndStepsThroughRealGo() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "source-debug-\(UUID().uuidString)")
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: root.appending(path: "projects.json")))
        let source = """
        package main
        import "fmt"
        func double(n int) int {
            const Huge = 1 << 100
            value := n * 2
            return value
        }
        func main() {
            start := 3
            result := double(start)
            fmt.Println(result)
        }
        """
        let snapshot = GoSourceSnapshot.singleFile(source)
        let project = GopherForgeProject(name: "Step through Go", files: snapshot.files, entryFile: "main.go", provenance: nil)
        defer { workspace.debugger.stop(); workspace.siteServer.stop(); try? FileManager.default.removeItem(at: root) }
        await workspace.prepare()
        XCTAssertTrue(workspace.open(project))
        await workspace.run(.run)
        XCTAssertEqual(workspace.lastResult?.stdout, "6\n")
        XCTAssertEqual(workspace.debugger.state, .idle, "no breakpoints must use the ordinary execution path")
        XCTAssertEqual(workspace.project?.files, project.files)

        workspace.debugger.toggle(file: "main.go", line: 10)
        let run = Task { await workspace.run(.run) }
        defer { workspace.debugger.stop() }
        try await stopped(workspace, line: 10)
        XCTAssertEqual(workspace.debugger.pause?.locals["start"], "3")
        XCTAssertNil(workspace.debugger.pause?.locals["result"])
        workspace.debugger.resume(step: .into)
        try await stopped(workspace, line: 5)
        XCTAssertEqual(workspace.debugger.pause?.point.function, "double")
        XCTAssertEqual(workspace.debugger.pause?.locals["n"], "3")
        XCTAssertEqual(workspace.debugger.pause?.frames.map(\.function), ["double", "main"])
        workspace.debugger.resume(step: .over)
        try await stopped(workspace, line: 6)
        XCTAssertEqual(workspace.debugger.pause?.locals["value"], "6")
        workspace.debugger.resume(step: .out)
        try await stopped(workspace, line: 11)
        XCTAssertEqual(workspace.debugger.pause?.locals["result"], "6")
        workspace.debugger.resume()
        await run.value
        XCTAssertTrue(workspace.lastResult?.succeeded == true, workspace.lastResult?.detail ?? "no result")
        XCTAssertEqual(workspace.lastResult?.stdout, "6\n")
        XCTAssertEqual(workspace.project?.files, project.files, "temporary probes must never reach autosaved source")
        let id = try XCTUnwrap(workspace.projectID)
        let restored = GoDebuggerModel()
        restored.openProject(id)
        XCTAssertEqual(restored.breakpoints["main.go"], [10])
        restored.removeAll()
        workspace.debugger.removeAll()
        await workspace.flush()
    }

    func testStopReleasesTheGuestAndAnUnusedLocalStillFailsBeforeInstrumentation() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "stop-debug-\(UUID().uuidString)")
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: root.appending(path: "projects.json")))
        defer { workspace.debugger.stop(); try? FileManager.default.removeItem(at: root) }
        await workspace.prepare()
        let source = "package main\nfunc main() {\n n := 0\n for {\n  n++\n }\n}\n"
        XCTAssertTrue(workspace.open(GopherForgeProject(name: "Stop", files: GoSourceSnapshot.singleFile(source).files, entryFile: "main.go", provenance: nil)))
        workspace.debugger.toggle(file: "main.go", line: 5)
        let run = Task { await workspace.run(.run) }
        try await stopped(workspace, line: 5)
        XCTAssertEqual(workspace.debugger.pause?.locals["n"], "0")
        workspace.debugger.stop()
        await run.value
        XCTAssertFalse(workspace.isRunning)
        XCTAssertFalse(workspace.lastResult?.succeeded ?? true)
        workspace.debugger.removeAll()
        let invalid = "package main\nfunc main() {\n unused := 1\n}\n"
        XCTAssertTrue(workspace.open(GopherForgeProject(name: "Unused", files: GoSourceSnapshot.singleFile(invalid).files, entryFile: "main.go", provenance: nil)))
        workspace.debugger.toggle(file: "main.go", line: 3)
        await workspace.run(.run)
        XCTAssertFalse(workspace.lastResult?.succeeded ?? true)
        XCTAssertTrue(workspace.lastResult?.diagnostics.contains { $0.message.contains("unused") } == true)
        workspace.debugger.removeAll()
        await workspace.flush()
    }

    func testBreakpointInsideAnotherGoroutineHasItsOwnStack() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "goroutine-debug-\(UUID().uuidString)")
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: root.appending(path: "projects.json")))
        defer { workspace.debugger.stop(); try? FileManager.default.removeItem(at: root) }
        await workspace.prepare()
        let source = "package main\nimport \"fmt\"\nfunc worker(done chan int) {\n n := 2\n done <- n\n}\nfunc main() {\n done := make(chan int)\n go worker(done)\n fmt.Println(<-done)\n}\n"
        XCTAssertTrue(workspace.open(GopherForgeProject(name: "Goroutine", files: GoSourceSnapshot.singleFile(source).files, entryFile: "main.go", provenance: nil)))
        workspace.debugger.toggle(file: "main.go", line: 5)
        let run = Task { await workspace.run(.run) }
        try await stopped(workspace, line: 5)
        XCTAssertEqual(workspace.debugger.pause?.locals["n"], "2")
        XCTAssertEqual(workspace.debugger.pause?.frames.map(\.function), ["worker"])
        XCTAssertGreaterThan(workspace.debugger.pause?.goroutine ?? 0, 1)
        workspace.debugger.resume()
        await run.value
        XCTAssertEqual(workspace.lastResult?.stdout, "2\n")
        workspace.debugger.removeAll()
        await workspace.flush()
    }

    private func stopped(_ workspace: WorkspaceModel, line: Int) async throws {
        for _ in 0..<600 {
            if workspace.debugger.state == .paused, workspace.debugger.pause?.point.line == line { return }
            if workspace.debugger.state == .finished { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let message = "Expected breakpoint at line \(line); state=\(workspace.debugger.state), pausedLine=\(workspace.debugger.pause?.point.line ?? -1), detail=\(workspace.lastResult?.detail ?? workspace.debugger.message)"
        workspace.debugger.stop()
        XCTFail(message)
        throw OfflineFrontendError.message(message)
    }
}
