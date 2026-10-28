import XCTest
@testable import GopherForge

final class InterviewCurriculumExpansionTests: XCTestCase {
    func testCoverageIsReachableWithIndependentReviewAndNoCompilerClaim() throws {
        XCTAssertEqual(InterviewCurriculumExpansion.lessonIDs.count, 34)
        let counts = ["system-design": 9, "clean-code-production": 4, "gin": 6, "blockchain": 7, "security": 4]
        for (unitID, count) in counts {
            XCTAssertEqual(GoCourseCatalog.unit(id: unitID)?.teachingLessons.count, count, unitID)
        }
        for id in InterviewCurriculumExpansion.lessonIDs {
            let reading = try XCTUnwrap(ReadingLessonCatalog.reading(for: id))
            XCTAssertEqual(reading.conceptTag, id)
            XCTAssertEqual(GoCourseCatalog.lessons.filter { $0.id == id }.count, 1)
            XCTAssertTrue(GoConcept.all.contains(id))
            XCTAssertNotNil(LessonSymbol.byConcept[id])
            XCTAssertFalse(reading.lesson.requiresCompiler)
            XCTAssertTrue(reading.lesson.canSelfReport)
            let pair = try XCTUnwrap(ReviewMatchCatalog.allPairs.first { $0.requiredLessonID == id })
            XCTAssertEqual(pair.answer, reading.reviewAnswer)
            XCTAssertLessThanOrEqual(pair.prompt.count, MatchingDrill.maximumPromptCharacters)
            XCTAssertLessThanOrEqual(pair.answer.count, MatchingDrill.maximumAnswerCharacters)
            XCTAssertNotNil(MistakeReviewCatalog.all.first { $0.id == "reading.question.\(id)" })
            XCTAssertEqual(Set([reading.reviewAnswer] + reading.wrongAnswers).count, 3)
            XCTAssertNotEqual(reading.hint, reading.nuance)
        }
    }

    func testInterviewExpansionHasStableIDsAndLinksToRealLessons() throws {
        let bank = InterviewPrepBank.shared
        XCTAssertEqual(InterviewCurriculumExpansion.questionIDs.count, 40)
        for id in InterviewCurriculumExpansion.questionIDs {
            let q = try XCTUnwrap(bank.questions.first { $0.id == id })
            XCTAssertTrue((1...4).contains(q.level))
            XCTAssertGreaterThanOrEqual(q.answerPoints.count, 3)
            XCTAssertGreaterThan(q.solution.count, 180)
            XCTAssertFalse(q.code.isEmpty)
            for link in q.references where link.hasPrefix("https://gopherforge.app/learn/") {
                XCTAssertNotNil(GoCourseCatalog.lesson(id: String(link.dropFirst("https://gopherforge.app/learn/".count))), id)
            }
        }
        for topic in ["gin", "blockchain", "security"] {
            XCTAssertFalse(bank.filtered(topic: topic, level: 0, search: "").isEmpty)
        }
    }
}
