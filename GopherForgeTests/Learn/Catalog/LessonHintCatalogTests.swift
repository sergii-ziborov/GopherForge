import XCTest
@testable import GopherForge

final class LessonHintCatalogTests: XCTestCase {
    func testEveryLessonHasAnAuthoredHint() {
        let missing = Set(GoCourseCatalog.lessons.map(\.id)).subtracting(LessonHintCatalog.authoredIDs)
        XCTAssertTrue(missing.isEmpty, "lessons without a hint: \(missing.sorted())")
    }

    func testNoAuthoredHintIsOrphaned() {
        let known = Set(GoCourseCatalog.lessons.map(\.id))
        let extras = LessonHintCatalog.authoredIDs.subtracting(known)
        XCTAssertTrue(extras.isEmpty, "hints for missing lessons: \(extras.sorted())")
    }

    func testEveryCompileLessonCanBeRealized() {
        for lesson in GoCourseCatalog.lessons where lesson.requiresCompiler {
            XCTAssertNotNil(
                LessonHintCatalog.realizeSource(for: lesson),
                "\(lesson.id) has no verified solution to Realize"
            )
        }
    }

    func testAPredictLessonHasNoRealizeSource() throws {
        let lesson = try XCTUnwrap(GoCourseCatalog.lessons.first { $0.isChallenge })
        XCTAssertNil(LessonHintCatalog.realizeSource(for: lesson), lesson.id)
    }

    func testHintsAndNuancesAreDistinctAndUsable() {
        for lesson in GoCourseCatalog.lessons {
            let hint = LessonHintCatalog.hint(for: lesson)
            XCTAssertEqual(hint.lessonID, lesson.id)
            XCTAssertGreaterThan(hint.hint.count, 20, lesson.id)
            XCTAssertGreaterThan(hint.nuance.count, 20, lesson.id)
            XCTAssertNotEqual(hint.hint, hint.nuance, lesson.id)
            XCTAssertLessThanOrEqual(hint.hint.count, 240, "\(lesson.id) hint is a paragraph")
            XCTAssertLessThanOrEqual(hint.nuance.count, 240, "\(lesson.id) nuance is a paragraph")
        }
    }

    func testSynthesizedFallbackIsObviouslyAFallback() {
        let fake = Lesson(
            id: "missing.example",
            title: "Missing",
            objective: "x",
            explanation: "A leftover explanation used only when a hint was not authored.",
            conceptTags: [GoConcept.varsUnused],
            task: .predict(source: "package main", question: "q", answer: "a"),
            idiomaticSolution: nil
        )
        let hint = LessonHintCatalog.synthesized(from: fake)
        XCTAssertTrue(hint.hint.contains("check"))
        XCTAssertTrue(hint.nuance.contains("leftover"))
    }
}

@MainActor
final class LessonModelTests: XCTestCase {
    private func compileLesson() throws -> Lesson {
        try XCTUnwrap(GoCourseCatalog.lesson(id: "core.switch"))
    }

    private func readingLesson() throws -> Lesson {
        try XCTUnwrap(GoCourseCatalog.lesson(id: "core.short-declaration"))
    }

    func testRealizePutsTheVerifiedSolutionInTheEditor() throws {
        let lesson = try compileLesson()
        let model = LessonModel(lesson: lesson, store: store())
        XCTAssertTrue(model.canRealize)
        XCTAssertNotEqual(model.editorText, lesson.verifiedSolution)
        model.realize()
        XCTAssertEqual(model.editorText, lesson.verifiedSolution)
        XCTAssertFalse(model.isCompleted, "Realize is a fill, not a pass")
    }

    func testRealizeOnAReadingLessonDoesNothing() throws {
        let lesson = try readingLesson()
        let model = LessonModel(lesson: lesson, store: store())
        let before = model.editorText
        XCTAssertFalse(model.canRealize)
        model.realize()
        XCTAssertEqual(model.editorText, before)
    }

    func testACompileLessonCannotBeTickedByHand() async throws {
        let lesson = try compileLesson()
        let model = LessonModel(lesson: lesson, store: store())
        XCTAssertFalse(model.canSelfReport)
        await model.markCompleted()
        XCTAssertFalse(model.isCompleted)
    }

    func testAReadingLessonCanBeTickedByHand() async throws {
        let lesson = try readingLesson()
        let model = LessonModel(lesson: lesson, store: store())
        XCTAssertTrue(model.canSelfReport)
        await model.markCompleted()
        XCTAssertTrue(model.isCompleted)
        XCTAssertFalse(model.isCompilerVerified)
    }

    func testAHandTickCanBeCleared() async throws {
        let lesson = try readingLesson()
        let model = LessonModel(lesson: lesson, store: store())
        await model.markCompleted()
        await model.clearCompletion()
        XCTAssertFalse(model.isCompleted)
    }

    func testTheHintOnTheModelIsTheAuthoredOne() throws {
        let lesson = try compileLesson()
        let model = LessonModel(lesson: lesson, store: store())
        XCTAssertEqual(model.hint.lessonID, lesson.id)
        XCTAssertTrue(model.hint.hint.contains("break") || model.hint.hint.contains("switch"))
    }

    func testCheckSnapshotUsesAStableReuseKey() throws {
        let lesson = try compileLesson()
        let model = LessonModel(lesson: lesson, store: store())
        let snapshot = try XCTUnwrap(lesson.checkSnapshot(source: model.editorText))
        XCTAssertEqual(snapshot.workspaceReuseKey, "lesson.core.switch")
        XCTAssertEqual(snapshot.entryFile, "main.go")
        XCTAssertTrue(snapshot.hasTests)
    }

    func testStarterIsWhatTheEditorOpensOn() throws {
        let lesson = try compileLesson()
        guard case let .compile(starter, _) = lesson.task else {
            return XCTFail("core.switch should be a compile lesson")
        }
        let model = LessonModel(lesson: lesson, store: store())
        XCTAssertEqual(model.editorText, starter)
    }

    func testRepeatedTapsStartOnlyOneCheckAndShowBusyImmediately() async throws {
        let lesson = try compileLesson()
        let runner = ControlledLessonTestRunner()
        let model = controlledModel(lesson: lesson, runner: runner)

        let firstTap = Task { await model.check() }
        await runner.waitForCallCount(1)
        XCTAssertTrue(model.isChecking, "the first tap must become visible before compilation finishes")

        let impatientSecondTap = Task { await model.check() }
        await impatientSecondTap.value
        let callsAfterSecondTap = await runner.callCount
        XCTAssertEqual(callsAfterSecondTap, 1, "a second tap must not queue stale work")

        await runner.finishNext(with: .lessonSuccess)
        await firstTap.value
        XCTAssertFalse(model.isChecking)
        XCTAssertTrue(model.result?.succeeded == true)
    }

    func testRealizeReusesTheVerifiedPrewarmInsteadOfCompilingForAnotherMinute() async throws {
        let lesson = try compileLesson()
        let runner = ControlledLessonTestRunner()
        let model = controlledModel(lesson: lesson, runner: runner)

        let prewarm = Task { await model.prewarm() }
        await runner.waitForCallCount(1)
        let prewarmedSource = await runner.source(at: 0)
        XCTAssertEqual(prewarmedSource, lesson.verifiedSolution)
        await runner.finishNext(with: .lessonSuccess)
        await prewarm.value

        let failedCheck = Task { await model.check() }
        await runner.waitForCallCount(2)
        await runner.finishNext(with: .lessonFailure)
        await failedCheck.value
        XCTAssertFalse(model.result?.succeeded == true)

        await model.realizeAndCheck()
        let callsAfterRealize = await runner.callCount
        XCTAssertEqual(callsAfterRealize, 2, "Realize should use the exact answer already tested by prewarm")
        XCTAssertTrue(model.result?.succeeded == true)
    }

    private func controlledModel(
        lesson: Lesson,
        runner: ControlledLessonTestRunner
    ) -> LessonModel {
        LessonModel(
            lesson: lesson,
            store: store(),
            toolchainStatus: ToolchainStatus(
                isReady: true,
                toolSize: 1,
                goVersion: "go-test",
                label: "Test toolchain",
                detail: "Controlled by the unit test."
            ),
            testRunner: { snapshot in await runner.run(snapshot) }
        )
    }

    private func store() -> LearningProgressStore {
        LearningProgressStore(
            storageURL: FileManager.default.temporaryDirectory
                .appending(path: "gopherforge-lesson-model-\(UUID().uuidString).json")
        )
    }
}

private actor ControlledLessonTestRunner {
    private var snapshots: [GoSourceSnapshot] = []
    private var pending: [CheckedContinuation<CompilationResult, Never>] = []

    var callCount: Int { snapshots.count }

    func source(at index: Int) -> String? {
        snapshots[index].files["main.go"]
    }

    func run(_ snapshot: GoSourceSnapshot) async -> CompilationResult {
        snapshots.append(snapshot)
        return await withCheckedContinuation { continuation in
            pending.append(continuation)
        }
    }

    func waitForCallCount(_ expected: Int) async {
        while snapshots.count < expected {
            await Task.yield()
        }
    }

    func finishNext(with result: CompilationResult) {
        pending.removeFirst().resume(returning: result)
    }
}

private extension CompilationResult {
    static let lessonSuccess = CompilationResult(
        succeeded: true,
        phase: .test,
        exitCode: 0,
        diagnostics: [],
        stdout: "ok",
        stderr: "",
        duration: .zero,
        detail: "2 of 2 tests passed."
    )

    static let lessonFailure = CompilationResult.failure(
        phase: .test,
        detail: "2 of 2 tests failed."
    )
}
