import XCTest
@testable import GopherForge

@MainActor final class PlaygroundContractTests: XCTestCase {
    func testLinksRequireExactTrustedOriginAndFragmentCapability() {
        let cap = String(repeating: "a", count: 24) + "." + String(repeating: "B", count: 32)
        XCTAssertEqual(PlaygroundLink.capability(PlaygroundLink.web(cap)), cap)
        XCTAssertEqual(PlaygroundLink.capability(URL(string: "gopherforge://playground#cap=" + cap)!), cap)
        for raw in ["https://evil.example/playground#cap=\(cap)", "https://gopherforge.app/other#cap=\(cap)", "https://gopherforge.app/playground?cap=\(cap)", "gopherforge://playground#cap=short"] {
            XCTAssertNil(PlaygroundLink.capability(URL(string: raw)!))
        }
    }
    func testLocalDraftRestoresExactUTF8WithoutTouchingAProjectLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "draft.json")
        let model = PlaygroundSession(storageURL: file)
        let source = "package main\n// e\u{301} is preserved as its original bytes\nfunc main() {}"
        model.update(source)
        let restored = PlaygroundSession(storageURL: file)
        XCTAssertTrue(restored.files["main.go"]!.utf8.elementsEqual(source.utf8))
        XCTAssertTrue(restored.dirty)
        XCTAssertNil(restored.room)
        XCTAssertFalse(restored.isRunning)
    }
    func testShareSnapshotWhitelistsKnownMarksAndEncodesEmptyPlacesAsNull() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("{\"ai.security\":\"revisit\",\"secret-token\":\"private\"}", forKey: "interview.preparation.selfAssessment.v1")
        defaults.set("private code", forKey: "editor.draft")
        defaults.set("owner-secret", forKey: "room.capability")
        let store = LearningProgressStore(storageURL: directory.appending(path: "learning.json"))
        let lesson = try XCTUnwrap(GoCourseCatalog.teachingLessons.first)
        try await store.record(LessonAttempt(lessonID: lesson.id, succeeded: true, mistakeTags: [], compileAttempts: 1, compilerVerified: true))
        let snapshot = try await LearningShareSnapshot.make(store: store, defaults: defaults)
        XCTAssertEqual(snapshot.completed, [lesson.id]); XCTAssertEqual(snapshot.compilerVerified, [lesson.id])
        XCTAssertEqual(snapshot.assessments, ["ai.security": "revisit"])
        let data = try JSONEncoder().encode(snapshot), text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("private")); XCTAssertFalse(text.contains("owner-secret"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(object["lastLessonID"] is NSNull); XCTAssertTrue(object["lastInterviewID"] is NSNull)
        let stillCompleted = try await store.completedLessonIDs()
        XCTAssertEqual(stillCompleted, Set([lesson.id]))
    }
    func testTwoNativeSeatsOnlyRunAfterTheirOwnExplicitAction() async throws {
        guard ProcessInfo.processInfo.environment["GOPHERFORGE_PLAYGROUND_RELAY_TESTS"] == "1" else { throw XCTSkip("Run the dedicated Playground QA scheme with its localhost relay.") }
        let endpoint = URL(string: "http://127.0.0.1:3064/api/playground")!
        // This integration test is selected with the local relay running; never uses a public/user room.
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let counts = RunCounts()
        let transport = PlaygroundTransport(endpoint: endpoint)
        let a = PlaygroundSession(transport: transport, storageURL: directory.appending(path: "a.json"), execute: { source, _ in
            await counts.record("a", source: source.files["main.go"] ?? "")
            return CompilationResult(succeeded: true, phase: .run, exitCode: 0, diagnostics: [], stdout: "output from A\n", stderr: "", duration: .zero, detail: "contract fixture")
        })
        let b = PlaygroundSession(transport: transport, storageURL: directory.appending(path: "b.json"), execute: { source, _ in
            await counts.record("b", source: source.files["main.go"] ?? "")
            return CompilationResult(succeeded: true, phase: .run, exitCode: 0, diagnostics: [], stdout: "output from B\n", stderr: "", duration: .zero, detail: "contract fixture")
        })
        await a.create(name: "Test device A")
        let url = try XCTUnwrap(a.shareURL, a.status)
        await b.join(url, name: "Test device B")
        XCTAssertNotNil(b.room, b.status)
        a.update("package main\nfunc main() { println(7) }")
        let published = await a.publish(); XCTAssertTrue(published, a.status)
        await b.poll()
        XCTAssertEqual(b.files["main.go"], a.files["main.go"])
        var observed = await counts.values(); XCTAssertEqual(observed, [:])
        await a.run(test: false); await b.poll()
        observed = await counts.values(); XCTAssertEqual(observed, ["a": 1])
        XCTAssertEqual(b.room?.runs.last?.stdout, "output from A\n")
        XCTAssertEqual(b.room?.runs.last?.device, "Test device A")
        await b.run(test: false); await a.poll()
        observed = await counts.values(); XCTAssertEqual(observed, ["a": 1, "b": 1])
        XCTAssertEqual(a.room?.runs.last?.device, "Test device B")
        let restored = PlaygroundSession(transport: transport, storageURL: directory.appending(path: "a.json"))
        XCTAssertEqual(restored.files, a.files); XCTAssertFalse(restored.isRunning)
        await a.close()
    }
    func testRealBundledGoRunPublishesToAnotherSeatWithoutRunningThere() async throws {
        guard ProcessInfo.processInfo.environment["GOPHERFORGE_PLAYGROUND_RELAY_TESTS"] == "1" else { throw XCTSkip("Run the dedicated Playground QA scheme with its localhost relay.") }
        let endpoint = URL(string: "http://127.0.0.1:3064/api/playground")!
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let transport = PlaygroundTransport(endpoint: endpoint), counts = RunCounts()
        let a = PlaygroundSession(transport: transport, storageURL: directory.appending(path: "real.json"))
        let b = PlaygroundSession(transport: transport, storageURL: directory.appending(path: "observer.json"), execute: { _, _ in
            await counts.record("unexpected", source: "")
            return .failure(phase: .run, detail: "Observer must not execute")
        })
        await a.create(name: "Native compiler device")
        let url = try XCTUnwrap(a.shareURL, a.status)
        await b.join(url, name: "Output-only observer")
        await a.run(test: false); await b.poll()
        XCTAssertEqual(a.room?.runs.last?.status, "finished", a.status + a.localOutput)
        XCTAssertTrue(b.room?.runs.last?.stdout.contains("Hello from my device") == true, b.status)
        let values = await counts.values(); XCTAssertEqual(values, [:])
        await a.close()
    }
}
private actor RunCounts {
    private var counts: [String: Int] = [:]
    func record(_ key: String, source: String) { counts[key, default: 0] += 1 }
    func values() -> [String: Int] { counts }
}
