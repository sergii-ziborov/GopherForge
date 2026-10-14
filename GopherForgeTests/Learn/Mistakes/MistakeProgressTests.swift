import XCTest
@testable import GopherForge

final class MistakeProgressTests: XCTestCase {
    private var url: URL!
    private var store: LearningProgressStore!

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "mistake-tests-\(UUID()).json")
        store = LearningProgressStore(storageURL: url)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: url) }

    func testOldProgressLoadsAndACompletedLessonPopulatesMatching() async throws {
        let lesson = "core.short-declaration"
        let attempt = LessonAttempt(lessonID: lesson, succeeded: true, compilerVerified: false)
        let legacy = try JSONSerialization.jsonObject(with: JSONEncoder.gopherForge.encode(attempt))
        try JSONSerialization.data(withJSONObject: ["attempts": [legacy]]).write(to: url)
        let progress = await LearnProgress(store: store)
        await progress.refresh()
        let completed = await progress.completed
        XCTAssertTrue(completed.contains(lesson))
        XCTAssertFalse(ReviewMatchCatalog.unlocked(completed: completed).isEmpty)
        let pending = await progress.pendingMistakeConcepts
        XCTAssertTrue(pending.isEmpty)
    }

    func testLessonDrillAndQuizMistakesAllReachTheSameQueue() async throws {
        try await store.record(LessonAttempt(lessonID: "collections.append-aliasing", succeeded: false,
                                             mistakeTags: [GoConcept.sliceAliasing], compileAttempts: 1))
        try await store.record(MatchingDrillResult(drillID: "review.core", completedAt: Date(), mistakes: 1,
                                                   mistakenConcepts: [GoConcept.varsUnused]))
        try await store.record(QuizResult(unitID: "errors", completedAt: Date(), correct: 0, total: 5,
                                          mistakenConcepts: [GoConcept.errorWrapping]))
        let pending = try await store.pendingMistakeConcepts()
        XCTAssertTrue(Set([GoConcept.sliceAliasing, GoConcept.varsUnused, GoConcept.errorWrapping]).isSubset(of: Set(pending)))
        let mastery = try await store.mastery()
        XCTAssertGreaterThan(mastery.first { $0.conceptTag == GoConcept.errorWrapping }?.mistakes ?? 0, 0)
    }

    func testCorrectAnswerClearsOnlyItsConceptAndSurvivesRelaunch() async throws {
        try await store.recordMistakes(conceptTags: [GoConcept.sliceCapacity, GoConcept.varsUnused])
        try await store.record(MistakeReviewAttempt(questionID: "coll.q.append", conceptTag: GoConcept.sliceCapacity, succeeded: true))
        let reopened = LearningProgressStore(storageURL: url)
        let pending = try await reopened.pendingMistakeConcepts()
        XCTAssertFalse(pending.contains(GoConcept.sliceCapacity))
        XCTAssertTrue(pending.contains(GoConcept.varsUnused))
        let history = try await reopened.correctionAttempts()
        XCTAssertTrue(history.contains { $0.questionID == "coll.q.append" && $0.succeeded })
        let completed = try await reopened.completedLessonIDs()
        XCTAssertTrue(completed.isEmpty, "a quiz answer must not pretend a compiler lesson passed")
    }

    func testAnUnfinishedWrongAnswerIsSavedAndANewMistakeReopensItsConcept() async throws {
        let tag = GoConcept.sliceCapacity
        try await store.record(MistakeReviewAttempt(questionID: "coll.q.append", conceptTag: tag, succeeded: false))
        let reopened = LearningProgressStore(storageURL: url)
        var pending = try await reopened.pendingMistakeConcepts()
        XCTAssertTrue(pending.contains(tag))
        try await reopened.record(MistakeReviewAttempt(questionID: "coll.q.append", conceptTag: tag, succeeded: true))
        pending = try await reopened.pendingMistakeConcepts()
        XCTAssertFalse(pending.contains(tag))
        try await reopened.recordMistakes(conceptTags: [tag])
        pending = try await reopened.pendingMistakeConcepts()
        XCTAssertTrue(pending.contains(tag))
    }

    func testResetClearsBothMistakesAndCorrectedAnswerHistory() async throws {
        try await store.recordMistakes(conceptTags: [GoConcept.varsUnused])
        try await store.record(MistakeReviewAttempt(questionID: "core.q.unused", conceptTag: GoConcept.varsUnused, succeeded: true))
        try await store.reset()
        let pending = try await store.pendingMistakeConcepts()
        let attempts = try await store.correctionAttempts()
        XCTAssertTrue(pending.isEmpty)
        XCTAssertTrue(attempts.isEmpty)
    }

    func testKnowledgeCheckFillsMatchingWithoutPretendingTheLessonPassed() async throws {
        let progress = await LearnProgress(store: store)
        try await progress.record(MistakeReviewAttempt(
            questionID: "core.q.short", conceptTag: GoConcept.shortDeclaration, succeeded: true
        ))
        let completed = await progress.completed
        let concepts = await progress.confirmedConcepts
        XCTAssertTrue(completed.isEmpty)
        XCTAssertEqual(concepts, [GoConcept.shortDeclaration])
        XCTAssertFalse(ReviewMatchCatalog.unlocked(completed: completed, confirmedConcepts: concepts).isEmpty)
    }
}
