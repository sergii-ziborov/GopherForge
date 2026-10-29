import XCTest
@testable import GopherForge

@MainActor
final class LessonDraftTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appending(path: "lesson-drafts-\(UUID())") }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    private func store() -> LearningProgressStore { LearningProgressStore(storageURL: root.appending(path: "progress.json")) }
    private func lesson(_ id: String = "draft.a", starter: String = "package main\n// starter\n") -> Lesson {
        Lesson(id: id, title: "Draft", objective: "Edit", explanation: "Example", conceptTags: [], task: .compile(starter: starter, hiddenTest: "package main"), idiomaticSolution: nil)
    }
    private func model(_ lesson: Lesson, store: LearningProgressStore? = nil) -> LessonModel {
        LessonModel(lesson: lesson, store: store ?? self.store(), toolchainStatus: ToolchainStatus(isReady: true, toolSize: 1, goVersion: "test", label: "Test", detail: "Controlled"), testRunner: { _ in .failure(phase: .test, detail: "controlled failure") })
    }
    func testEditedSourceRestoresAcrossNewStoresAndLessonsRemainIndependent() async throws {
        let a = model(lesson()), b = model(lesson("draft.b"))
        await a.loadProgress(); await b.loadProgress()
        a.editorText = "package main\n// my A\n"; b.editorText = "package main\n// my B\n"
        await a.saveDraft(); await b.saveDraft()
        let reopenedA = model(lesson()), reopenedB = model(lesson("draft.b"))
        await reopenedA.loadProgress(); await reopenedB.loadProgress()
        XCTAssertEqual(reopenedA.editorText, a.editorText)
        XCTAssertEqual(reopenedB.editorText, b.editorText)
        XCTAssertTrue(reopenedA.draftRestored)
    }
    func testNewContentPreservesOldCodeAndExplicitResetUsesNewStarterWithoutClearingHistory() async throws {
        let progress = store(), original = lesson()
        let first = model(original, store: progress); await first.loadProgress()
        first.editorText = "package main\n// prior work\n"; await first.saveDraft()
        try await progress.record(LessonAttempt(lessonID: original.id, succeeded: true, compilerVerified: true))
        let changed = model(lesson(starter: "package main\n// new template\n"), store: progress)
        await changed.loadProgress()
        XCTAssertEqual(changed.editorText, first.editorText)
        XCTAssertTrue(changed.draftContentChanged)
        changed.resetDraft(); await changed.saveDraft()
        XCTAssertTrue(changed.editorText.contains("new template"))
        XCTAssertFalse(changed.draftContentChanged)
        let completed = try await progress.completedLessonIDs(); XCTAssertTrue(completed.contains(original.id))
    }
    func testInsertedAnswerKeepsOwnCodeAndAssistanceThroughFailureAndReopen() async throws {
        let authored = try XCTUnwrap(GoCourseCatalog.lessons.first { $0.requiresCompiler && $0.verifiedSolution != nil })
        let progress = store(), attempt = model(authored, store: progress)
        await attempt.loadProgress()
        let own = "package main\n// my attempt before the answer\n"
        attempt.editorText = own; attempt.realize(); await attempt.saveDraft()
        await attempt.check()
        let history = try await progress.attempts()
        XCTAssertEqual(history.first?.assistanceLevel, .solutionInserted)
        let reopened = model(authored); await reopened.loadProgress()
        XCTAssertEqual(reopened.assistanceLevel, .solutionInserted)
        XCTAssertEqual(reopened.ownTextBeforeSolution, own)
        reopened.restoreOwnCode(); XCTAssertEqual(reopened.editorText, own)
        XCTAssertEqual(reopened.assistanceLevel, .solutionInserted, "restoring or editing does not erase observed assistance")
    }
    func testStaleScreenCannotOverwriteNewScreenAndItsSourceIsRetainedSeparately() async throws {
        let drafts = LessonDraftStore(folder: root.appending(path: "separate")), id = "draft.same"
        let old = try await drafts.open(lessonID: id), newer = try await drafts.open(lessonID: id)
        func draft(_ source: String) -> LessonDraft { LessonDraft(lessonID: id, contentRevision: "1", text: source, ownTextBeforeSolution: nil, assistance: .none, updatedAt: Date()) }
        try await drafts.save(draft("new window"), token: newer.token, revision: 1)
        do { try await drafts.save(draft("old window"), token: old.token, revision: 10); XCTFail("stale screen") } catch { }
        let reopened = try await drafts.open(lessonID: id); XCTAssertEqual(reopened.draft?.text, "new window")
        let files = try FileManager.default.contentsOfDirectory(at: root.appending(path: "separate"), includingPropertiesForKeys: nil)
        let recovery = try XCTUnwrap(files.first { $0.lastPathComponent.contains("recovery-") })
        XCTAssertEqual(try JSONDecoder.gopherForge.decode(LessonDraft.self, from: Data(contentsOf: recovery)).text, "old window")
    }
    func testReferenceExposureIsSeparateFromAnEarlierCompilerResult() async throws {
        let progress = store(), attempt = model(lesson(), store: progress)
        await attempt.loadProgress(); await attempt.check()
        let before = try await progress.attempts()
        XCTAssertEqual(before.first?.assistanceLevel, LessonAssistance.none)
        attempt.noteSolutionRevealed(); await attempt.check()
        let after = try await progress.attempts()
        XCTAssertEqual(after.first?.assistanceLevel, .solutionRevealed)
        XCTAssertEqual(after.last?.assistanceLevel, LessonAssistance.none)
    }

    func testOldAttemptHasUnknownAssistanceAndFutureDraftIsNotOverwritten() async throws {
        let old = LessonAttempt(lessonID: "old", succeeded: true, compileAttempts: 1)
        let decoded = try JSONDecoder.gopherForge.decode(LessonAttempt.self, from: JSONEncoder.gopherForge.encode(old))
        XCTAssertNil(decoded.assistanceLevel)
        let drafts = LessonDraftStore(folder: root.appending(path: "future"))
        let session = try await drafts.open(lessonID: "future")
        try await drafts.save(LessonDraft(lessonID: "future", contentRevision: "1", text: "saved", ownTextBeforeSolution: nil, assistance: .none, updatedAt: Date()), token: session.token, revision: 1)
        let url = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root.appending(path: "future"), includingPropertiesForKeys: nil).first { $0.pathExtension == "json" })
        let before = try Data(contentsOf: url)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: before) as? [String: Any]); object["schemaVersion"] = 99
        let future = try JSONSerialization.data(withJSONObject: object); try future.write(to: url)
        do { _ = try await drafts.open(lessonID: "future"); XCTFail("unknown schema") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), future)
    }
}
