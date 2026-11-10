import XCTest
@testable import GopherForge

final class DevOpsShellTests: XCTestCase {
    func testActualBundledWasiShellChangesFilesAndReportsIndependentChecks() async throws {
        let lab = try XCTUnwrap(CourseLibrary.shared.packages.flatMap(\.labs).first { $0.id == "logs-pipeline" })
        let result = try await DevOpsShellRunner.shared.run(source: lab.starter, state: .initial(lab), cancellation: WasiCancellation())
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "ERROR bad-token\nERROR timeout\n")
        XCTAssertEqual(result.state.files["/lab/errors.txt"], "ERROR bad-token\nERROR timeout\n")
    }
    func testWasiGuestCannotAccessItsControlFilesOrHostPaths() async throws {
        let lab = try XCTUnwrap(CourseLibrary.shared.packages.flatMap(\.labs).first)
        for source in ["cat /control/request.json", "echo wrong > /control/response.json", "cat /etc/passwd"] {
            let result = try await DevOpsShellRunner.shared.run(source: source, state: .initial(lab), cancellation: WasiCancellation())
            XCTAssertNotEqual(result.status, 0)
            XCTAssertTrue(result.stdout.isEmpty)
        }
    }
    func testWasiLoopBudgetAndStopToken() async throws {
        let lab = try XCTUnwrap(CourseLibrary.shared.packages.flatMap(\.labs).first)
        let result = try await DevOpsShellRunner.shared.run(source: "while true; do :; done", state: .initial(lab), cancellation: WasiCancellation())
        XCTAssertEqual(result.status, 2)
        XCTAssertTrue(result.stderr.contains("256-step"))
        let token = WasiCancellation(); token.cancel()
        let stopped = try await DevOpsShellRunner.shared.run(source: "echo should-not-run > forbidden", state: .initial(lab), cancellation: token)
        XCTAssertTrue(stopped.stderr.contains("stopped by user"))
        XCTAssertNil(stopped.state.files["/lab/forbidden"])
    }
    @MainActor func testLabPersistenceResetAndActualResultChecks() async throws {
        let lab = try XCTUnwrap(CourseLibrary.shared.packages.flatMap(\.labs).first { $0.id == "readiness-gate" })
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "state.json")
        let session = DevOpsLabSession(lab: lab, storage: url)
        await session.run()
        XCTAssertEqual(session.state.files["/lab/rollout.txt"], "blocked\n")
        XCTAssertFalse(session.checks.allSatisfy(\.passed))
        session.source = "touch health/ready.flag\n" + lab.starter
        await session.run()
        XCTAssertTrue(session.checks.allSatisfy(\.passed))
        let reopened = DevOpsLabSession(lab: lab, storage: url)
        XCTAssertTrue(reopened.checks.allSatisfy(\.passed))
        XCTAssertEqual(reopened.source, session.source)
        reopened.source = "echo an-unexecuted-draft"
        reopened.saveDraft()
        XCTAssertEqual(DevOpsLabSession(lab: lab, storage: url).source, "echo an-unexecuted-draft")
        reopened.reset()
        XCTAssertNil(reopened.state.files["/lab/rollout.txt"])
        XCTAssertFalse(reopened.checks.allSatisfy(\.passed))
    }
    @MainActor func testStaleWindowCannotOverwriteANewerSavedDraft() throws {
        let lab = try XCTUnwrap(CourseLibrary.shared.packages.flatMap(\.labs).first)
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "state.json")
        let first = DevOpsLabSession(lab: lab, storage: url)
        let stale = DevOpsLabSession(lab: lab, storage: url)
        first.source = "echo first accepted draft"; first.saveDraft()
        stale.source = "echo stale draft"; stale.saveDraft()
        XCTAssertTrue(stale.status?.contains("Another window") == true)
        XCTAssertEqual(DevOpsLabSession(lab: lab, storage: url).source, first.source)
    }
    @MainActor func testScratchpadHasValidInitialPathsAndRunsRealFileCommands() async throws {
        let lab = DevOpsHomeView.scratchpad
        let initial = DevOpsLabState.initial(lab)
        try initial.validate()
        XCTAssertNotNil(initial.files["/lab/README.txt"])
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = DevOpsLabSession(lab: lab, storage: root.appending(path: "scratch.json"))
        session.source = "mkdir notes; echo hello > notes/hello.txt; cat notes/hello.txt"
        await session.run()
        XCTAssertEqual(session.state.files["/lab/notes/hello.txt"], "hello\n")
        XCTAssertTrue(session.transcript.contains("hello\n"))
        XCTAssertTrue(session.transcript.contains("exit 0"))
        let restored = DevOpsLabSession(lab: lab, storage: root.appending(path: "scratch.json"))
        XCTAssertEqual(restored.state.files["/lab/notes/hello.txt"], "hello\n")
    }

}
