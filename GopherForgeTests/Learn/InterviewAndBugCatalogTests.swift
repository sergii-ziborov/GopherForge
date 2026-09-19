import XCTest
@testable import GopherForge

/// The two additions to practice, checked the way the rest of the content is:
/// content nobody can get wrong is worth more than content nobody has read.
final class InterviewAndBugCatalogTests: XCTestCase {
    // MARK: - Spot the bug

    /// The whole game rests on this index. Off by one and it marks the wrong
    /// line green, which teaches the opposite of the intended lesson.
    func testEveryFaultyLineIsInsideItsProgram() {
        for round in SpotTheBugCatalog.all {
            XCTAssertTrue(
                round.lines.indices.contains(round.faultyLine),
                "\(round.id) points at line \(round.faultyLine) of \(round.lines.count)"
            )
        }
    }

    func testEveryFaultyLineHasCodeOnIt() {
        for round in SpotTheBugCatalog.all {
            let line = round.lines[round.faultyLine].trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(line.isEmpty, "\(round.id) blames a blank line")
        }
    }

    func testEveryRoundExplainsItselfAndBelongsToAUnit() {
        let unitIDs = Set(GoCourseCatalog.units.map(\.id))
        for round in SpotTheBugCatalog.all {
            XCTAssertFalse(round.explanation.isEmpty, "\(round.id) has no explanation")
            XCTAssertFalse(round.brief.isEmpty, "\(round.id) does not say what it should do")
            XCTAssertTrue(unitIDs.contains(round.unitID), "\(round.id) is in unit \(round.unitID)")
        }
    }

    func testRoundIdentifiersAreUnique() {
        let ids = SpotTheBugCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "two rounds share an id")
    }

    /// A miss feeds the review queue by concept, so a concept no lesson teaches
    /// would schedule practice that does not exist.
    func testEveryBugConceptIsTaughtByALesson() {
        let tags = Set(SpotTheBugCatalog.all.map(\.conceptTag))
        let untaught = tags.subtracting(GoCourseCatalog.taughtConcepts)
        XCTAssertTrue(untaught.isEmpty, "bug concepts with no lesson: \(untaught.sorted())")
    }

    // MARK: - Interview questions

    func testEveryInterviewQuestionHasAnAnswerAndATrap() {
        for question in InterviewCatalog.all {
            XCTAssertFalse(question.prompt.isEmpty, "\(question.id) has no question")
            XCTAssertGreaterThanOrEqual(
                question.answerPoints.count, 2,
                "\(question.id) answers in one point; an interview answer has parts"
            )
            XCTAssertFalse(
                question.trap.isEmpty,
                "\(question.id) names no wrong answer, which is half of what makes it useful"
            )
        }
    }

    func testInterviewIdentifiersAreUniqueAndUnitsExist() {
        let ids = InterviewCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "two interview questions share an id")

        let unitIDs = Set(GoCourseCatalog.units.map(\.id))
        for question in InterviewCatalog.all {
            XCTAssertTrue(
                unitIDs.contains(question.unitID),
                "\(question.id) is in unit \(question.unitID)"
            )
        }
    }

    func testEveryInterviewConceptIsTaughtByALesson() {
        let tags = Set(InterviewCatalog.all.map(\.conceptTag))
        let untaught = tags.subtracting(GoCourseCatalog.taughtConcepts)
        XCTAssertTrue(untaught.isEmpty, "interview concepts with no lesson: \(untaught.sorted())")
    }

    // MARK: - How they reach the learner

    func testPracticeOffersBothAndGatesThemDifferently() {
        let items = PracticeCatalog.items

        let bugs = items.filter { if case .spotTheBug = $0.kind { return true } else { return false } }
        let interviews = items.filter { if case .interview = $0.kind { return true } else { return false } }

        XCTAssertFalse(bugs.isEmpty, "the bug hunt should be reachable from practice")
        XCTAssertFalse(interviews.isEmpty, "interview questions should be reachable from practice")

        XCTAssertTrue(
            bugs.allSatisfy { $0.unlocksAfter == 0 },
            "reading code and noticing what is off does not need the unit read first"
        )
        XCTAssertTrue(
            interviews.allSatisfy { $0.unlocksAfter > 0 },
            "explaining something you have not built is how people learn to recite"
        )
    }

    /// A session reports what it got wrong, and nothing it got right.
    @MainActor
    func testASessionReportsOnlyTheConceptsItMissed() {
        let rounds = Array(SpotTheBugCatalog.all.prefix(2))
        let session = SpotTheBugSession(rounds: rounds)

        session.choose(line: rounds[0].faultyLine)
        session.advance()
        let wrongLine = rounds[1].faultyLine == 0 ? 1 : 0
        session.choose(line: wrongLine)
        session.advance()

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.correctCount, 1)
        XCTAssertEqual(session.missedConceptTags, [rounds[1].conceptTag])
        XCTAssertEqual(session.result.mistakes, 1)
    }

    @MainActor
    func testAGuessCannotBeTakenBack() {
        let rounds = Array(SpotTheBugCatalog.all.prefix(1))
        let session = SpotTheBugSession(rounds: rounds)
        let wrongLine = rounds[0].faultyLine == 0 ? 1 : 0

        session.choose(line: wrongLine)
        session.choose(line: rounds[0].faultyLine)

        XCTAssertEqual(
            session.currentAnswer?.chosenLine, wrongLine,
            "the value of the game is the moment before the guess"
        )
    }
}
