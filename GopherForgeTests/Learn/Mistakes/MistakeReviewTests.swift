import XCTest
@testable import GopherForge

@MainActor
final class MistakeReviewTests: XCTestCase {
    func testEveryQuestionHasThreeDistinctAnswersAndAnExplanation() {
        for item in MistakeReviewCatalog.all {
            let question = item.question
            XCTAssertEqual(question.options.count, 3, item.id)
            XCTAssertEqual(Set(question.options).count, 3, item.id)
            XCTAssertTrue(question.options.indices.contains(question.correctIndex), item.id)
            XCTAssertFalse(question.explanation.isEmpty, item.id)
        }
        XCTAssertEqual(Set(MistakeReviewCatalog.all.map(\.id)).count, MistakeReviewCatalog.all.count)
    }

    func testEveryKnownCompilerOrCourseConceptHasACorrectionQuestion() {
        let covered = Set(MistakeReviewCatalog.all.map { $0.question.conceptTag })
        XCTAssertTrue(GoConcept.all.isSubset(of: covered), "Missing \(GoConcept.all.subtracting(covered))")
    }

    func testAWrongAnswerStaysOnItsQuestionUntilCorrected() throws {
        let items = Array(MistakeReviewCatalog.all.prefix(2))
        let session = MistakeReviewSession(questions: items)
        let question = try XCTUnwrap(session.current?.question)
        let wrong = (question.correctIndex + 1) % 3
        XCTAssertEqual(session.attempt(for: wrong)?.succeeded, false)
        session.advance(after: wrong)
        XCTAssertEqual(session.current?.id, items[0].id)
        XCTAssertEqual(session.index, 0)
        XCTAssertEqual(session.wrongAttempts, 1)
        XCTAssertTrue(session.rejectedOptions.contains(wrong))
        XCTAssertNil(session.attempt(for: wrong), "a disabled wrong option must not be recorded twice")
        session.advance(after: question.correctIndex)
        XCTAssertEqual(session.current?.id, items[1].id)
        XCTAssertTrue(session.rejectedOptions.isEmpty)
        XCTAssertEqual(session.progress, 0.5)
    }

    func testCorrectAnswersMoveToTheEndAndInvalidAnswersDoNothing() {
        let session = MistakeReviewSession(questions: Array(MistakeReviewCatalog.all.prefix(3)))
        XCTAssertNil(session.attempt(for: -1))
        XCTAssertNil(session.attempt(for: 3))
        session.advance(after: 99)
        XCTAssertEqual(session.index, 0)
        while let item = session.current { session.advance(after: item.question.correctIndex) }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.progress, 1)
        XCTAssertEqual(session.wrongAttempts, 0)
    }

    func testPendingQueueAsksOnlyForTheMistakenConceptsInOrder() {
        let tags = [GoConcept.sliceCapacity, GoConcept.shortDeclaration]
        let items = MistakeReviewCatalog.pendingQuestions(concepts: tags, history: [])
        XCTAssertEqual(items.map { $0.question.conceptTag }, tags)
    }

    func testCorrectedQuestionDoesNotBlockTheNextKnowledgeCheck() throws {
        let first = try XCTUnwrap(MistakeReviewCatalog.practiceQuestions(completed: [], history: []).first)
        let history = [MistakeReviewAttempt(questionID: first.id, conceptTag: first.question.conceptTag, succeeded: true)]
        let next = MistakeReviewCatalog.practiceQuestions(completed: [], history: history)
        XCTAssertNotEqual(next.first?.id, first.id)
        XCTAssertFalse(next.isEmpty)
    }

    func testLeavingAnUnansweredMistakeReturnsToThatExactQuestion() throws {
        let first = try XCTUnwrap(MistakeReviewCatalog.all.first)
        let history = [MistakeReviewAttempt(questionID: first.id, conceptTag: first.question.conceptTag, succeeded: false)]
        let queue = MistakeReviewCatalog.pendingQuestions(concepts: [first.question.conceptTag], history: history)
        XCTAssertEqual(queue.first?.id, first.id)
    }
}
