import XCTest
@testable import GopherForge

/// Marking a lesson done, and the course seeing it.
///
/// The bug these were written for: a tick was written to disk and nothing on
/// screen changed. The course screen loaded the completed set once and handed
/// it down by value, so the unit list was still holding the copy it was built
/// with — progress only appeared after relaunching the app.
final class LessonCompletionTests: XCTestCase {
    private var storeURL: URL!
    private var store: LearningProgressStore!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-tests-\(UUID().uuidString)")
            .appending(path: "progress.json")
        store = LearningProgressStore(storageURL: storeURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }

    private func aCompileLesson() throws -> Lesson {
        try XCTUnwrap(
            GoCourseCatalog.lessons.first(where: \.isJudgedByCompiler),
            "the course should contain a compile lesson"
        )
    }

    // MARK: - What the store records

    func testAHandMarkedLessonIsCompleteButNotCompilerVerified() async throws {
        let lesson = try aCompileLesson()
        let progress = await LearnProgress(store: store)

        await progress.markCompleted(lesson)

        let isCompleted = await progress.isCompleted(lesson.id)
        let isVerified = await progress.isCompilerVerified(lesson.id)
        XCTAssertTrue(isCompleted, "the learner said they did it, so it is done")
        XCTAssertFalse(isVerified, "the compiler never ran; the app must not say it did")
    }

    func testACompilerPassIsRecordedAsVerified() async throws {
        let lesson = try aCompileLesson()
        try await store.record(
            LessonAttempt(
                lessonID: lesson.id,
                succeeded: true,
                compileAttempts: 2,
                compilerVerified: true
            )
        )

        let verified = try await store.compilerVerifiedLessonIDs()
        XCTAssertTrue(verified.contains(lesson.id))
    }

    /// An attempt written before self-marking existed carries no flag, and
    /// must not be demoted: everything with a compile behind it was verified.
    func testAnOlderAttemptIsStillTreatedAsVerified() {
        let old = LessonAttempt(lessonID: "x", succeeded: true, compileAttempts: 3)

        XCTAssertTrue(old.isCompilerVerified)
        XCTAssertFalse(old.isSelfReported)
    }

    // MARK: - Undoing

    func testAHandMarkedLessonCanBeUndone() async throws {
        let lesson = try aCompileLesson()
        let progress = await LearnProgress(store: store)
        await progress.markCompleted(lesson)

        await progress.clearCompletion(lesson)

        let isCompleted = await progress.isCompleted(lesson.id)
        XCTAssertFalse(isCompleted)
    }

    /// A pass the compiler witnessed happened. Forgetting it on request would
    /// throw away the evidence review is built from.
    func testACompilerPassSurvivesAnUndo() async throws {
        let lesson = try aCompileLesson()
        try await store.record(
            LessonAttempt(
                lessonID: lesson.id,
                succeeded: true,
                compileAttempts: 1,
                compilerVerified: true
            )
        )

        try await store.clearSelfReportedCompletion(lessonID: lesson.id)

        let completed = try await store.completedLessonIDs()
        XCTAssertTrue(completed.contains(lesson.id))
    }

    // MARK: - What the course sees

    /// The regression this file exists for.
    func testMarkingALessonMovesTheUnitsCount() async throws {
        let unit = try XCTUnwrap(GoCourseCatalog.units.first)
        let lesson = try XCTUnwrap(unit.teachingLessons.first)
        let progress = await LearnProgress(store: store)
        await progress.refresh()

        let before = await progress.completedCount(in: unit)
        await progress.markCompleted(lesson)
        let after = await progress.completedCount(in: unit)

        XCTAssertEqual(before, 0)
        XCTAssertEqual(after, 1, "the unit should count the lesson the moment it is marked")
    }

    /// Four of the seven units had no lesson that could be ticked at all,
    /// because every one of their lessons was judged by the compiler.
    func testEveryUnitHasSomethingItsLearnerCanMark() {
        for unit in GoCourseCatalog.units {
            XCTAssertFalse(
                unit.teachingLessons.isEmpty,
                "\(unit.id) has no teaching lessons"
            )
        }
        XCTAssertFalse(GoCourseCatalog.units.isEmpty)
    }

    // MARK: - Badges stay honest

    /// A hand-marked lesson records no compile attempts and no mistakes, which
    /// looks exactly like a flawless first try unless the flag is read.
    func testASelfReportedPassIsNotAFirstTryCompile() {
        let stats = LearnerStatsBuilder.build(
            attempts: [
                LessonAttempt(
                    lessonID: "a",
                    succeeded: true,
                    compileAttempts: 0,
                    compilerVerified: false
                )
            ],
            mastery: [],
            drills: [],
            runs: []
        )

        XCTAssertEqual(stats.lessonsPassed, 1, "it still counts as passed")
        XCTAssertEqual(stats.lessonsPassedFirstTry, 0, "but not as a clean first compile")
    }

    func testACleanCompilerPassStillCountsAsFirstTry() {
        let stats = LearnerStatsBuilder.build(
            attempts: [
                LessonAttempt(
                    lessonID: "a",
                    succeeded: true,
                    compileAttempts: 1,
                    compilerVerified: true
                )
            ],
            mastery: [],
            drills: [],
            runs: []
        )

        XCTAssertEqual(stats.lessonsPassedFirstTry, 1)
    }
}
