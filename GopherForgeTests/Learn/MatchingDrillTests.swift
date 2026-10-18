import XCTest
@testable import GopherForge

/// The matching drill's rules, and the content invariants the board depends on.
///
/// The session is main-actor isolated because it drives a view; the test class
/// joins it rather than hopping per call, which would let assertions interleave
/// with the state they are asserting on.
@MainActor
final class MatchingDrillTests: XCTestCase {
    /// Deterministic layout: without pinning the order a test cannot say which
    /// tile it is tapping.
    private func session(_ drill: MatchingDrill) -> MatchingDrillSession {
        MatchingDrillSession(drill: drill, shuffle: { $0 })
    }

    private let drill = MatchingDrill(
        id: "test.drill",
        title: "Test",
        subtitle: "Pairs",
        unitID: "core",
        pairs: [
            MatchingPair(id: "a", prompt: "A", answer: "first", conceptTag: "t.a"),
            MatchingPair(id: "b", prompt: "B", answer: "second", conceptTag: "t.b"),
        ]
    )

    func testARightPairStaysMatched() {
        let session = session(drill)

        session.select(session.prompts[0])
        session.select(session.answers[0])

        XCTAssertEqual(session.state(of: session.prompts[0]), .matched)
        XCTAssertEqual(session.state(of: session.answers[0]), .matched)
        XCTAssertEqual(session.mistakes, 0)
        XCTAssertFalse(session.isComplete, "one of two pairs is not complete")
    }

    func testAWrongPairIsCountedAgainstBothConcepts() {
        let session = session(drill)

        session.select(session.prompts[0])
        session.select(session.answers[1])

        XCTAssertEqual(session.mistakes, 1)
        XCTAssertEqual(session.mistakenConcepts, ["t.a", "t.b"])
        XCTAssertEqual(session.state(of: session.prompts[0]), .rejected)
        XCTAssertNil(session.selectedPromptID, "a resolved attempt should clear the selection")
    }

    /// Tiles are never removed, so a matched one must simply refuse to react.
    func testTappingAMatchedTileDoesNothing() {
        let session = session(drill)
        session.select(session.prompts[0])
        session.select(session.answers[0])

        session.select(session.prompts[0])

        XCTAssertNil(session.selectedPromptID)
        XCTAssertEqual(session.state(of: session.prompts[0]), .matched)
    }

    func testTappingTheSameTileTwiceDeselectsIt() {
        let session = session(drill)

        session.select(session.prompts[1])
        session.select(session.prompts[1])

        XCTAssertNil(session.selectedPromptID, "a mis-tap should cost nothing")
        XCTAssertEqual(session.mistakes, 0)
    }

    func testAPerfectRunIsCompleteWithNoMistakes() {
        let session = session(drill)

        for index in session.prompts.indices {
            session.select(session.prompts[index])
            session.select(session.answers[index])
        }

        XCTAssertTrue(session.isComplete)
        XCTAssertTrue(session.isPerfect)
        XCTAssertEqual(session.progress, 1)
        XCTAssertTrue(session.result().isPerfect)
    }

    // MARK: - Content

    /// The board gives every tile the same height and never scrolls a tile out
    /// of a row. Both promises are content constraints, so they are checked
    /// against the content rather than hoped for.
    func testEveryAuthoredTileFitsItsBudget() {
        for drill in MatchingDrillCatalog.drills + ReviewMatchCatalog.rounds {
            XCTAssertLessThanOrEqual(
                drill.pairs.count, MatchingDrill.maximumPairs,
                "\(drill.id) has more pairs than a board shows without scrolling"
            )
            for pair in drill.pairs {
                XCTAssertLessThanOrEqual(
                    pair.prompt.count, MatchingDrill.maximumPromptCharacters,
                    "\(pair.id) prompt is too long for a fixed-height tile: \(pair.prompt)"
                )
                XCTAssertLessThanOrEqual(
                    pair.answer.count, MatchingDrill.maximumAnswerCharacters,
                    "\(pair.id) answer is too long for a fixed-height tile: \(pair.answer)"
                )
            }
        }
        for pair in ReviewMatchCatalog.allPairs {
            XCTAssertLessThanOrEqual(pair.prompt.count, MatchingDrill.maximumPromptCharacters, pair.id)
            XCTAssertLessThanOrEqual(pair.answer.count, MatchingDrill.maximumAnswerCharacters, pair.id)
        }
    }

    func testDrillIdentifiersAndPairsAreUnique() {
        let drills = MatchingDrillCatalog.drills + ReviewMatchCatalog.rounds
        let drillIDs = drills.map(\.id)
        XCTAssertEqual(Set(drillIDs).count, drillIDs.count)

        let pairIDs = MatchingDrillCatalog.drills.flatMap(\.pairs).map(\.id)
            + ReviewMatchCatalog.allPairs.map(\.id)
        XCTAssertEqual(Set(pairIDs).count, pairIDs.count, "pair ids must be unique across drills")
    }

    /// A drill's answers have to be distinct, or two tiles are both correct for
    /// one prompt and the board calls one of them wrong.
    func testNoDrillRepeatsAnAnswer() {
        for drill in MatchingDrillCatalog.drills + ReviewMatchCatalog.rounds {
            let answers = drill.pairs.map(\.answer)
            XCTAssertEqual(Set(answers).count, answers.count, "\(drill.id) repeats an answer")
        }
    }

    /// A drill mistake goes into the same review queue a compiler mistake does,
    /// and review looks the concept up in the course. A tag no lesson teaches
    /// is therefore a dead end: the learner is told to practise something the
    /// app cannot offer.
    func testEveryDrillConceptIsOneTheCourseKnows() {
        let known = Set(GoCourseCatalog.lessons.flatMap(\.conceptTags))
        for drill in MatchingDrillCatalog.drills + ReviewMatchCatalog.rounds {
            for pair in drill.pairs {
                XCTAssertTrue(
                    known.contains(pair.conceptTag),
                    "\(pair.id) tags \(pair.conceptTag), which no lesson teaches"
                )
            }
        }
    }

    func testReviewBoardsAreFivePairsTiedToRealLessons() throws {
        XCTAssertGreaterThanOrEqual(
            ReviewMatchCatalog.rounds.count, ReviewMatchCatalog.maximumRounds
        )
        for drill in ReviewMatchCatalog.rounds {
            XCTAssertEqual(drill.pairs.count, ReviewMatchCatalog.pairsPerRound, drill.id)
            for pair in drill.pairs {
                let lessonID = try XCTUnwrap(pair.requiredLessonID, "\(pair.id) has no lesson")
                XCTAssertNotNil(
                    GoCourseCatalog.lesson(id: lessonID),
                    "\(pair.id) requires \(lessonID), which is not a lesson"
                )
            }
        }
    }

    func testReviewDealsNothingBeforeAnyLessonIsDone() {
        XCTAssertTrue(ReviewMatchCatalog.unlocked(completed: []).isEmpty)
    }

    func testReviewStartsBeforeFiveLessonsAreDone() {
        let coreLessons = Set(ReviewMatchCatalog.core.pairs.compactMap(\.requiredLessonID))
        XCTAssertEqual(coreLessons.count, 5)
        XCTAssertTrue(ReviewMatchCatalog.unlocked(completed: []).isEmpty)
        let four = Set(coreLessons.dropLast())
        XCTAssertFalse(ReviewMatchCatalog.unlocked(completed: four).isEmpty)
        let boards = ReviewMatchCatalog.unlocked(completed: coreLessons)
        XCTAssertEqual(boards.first?.id, "review.core")
    }

    func testReviewNeverDealsAPairFromAnUnfinishedLesson() throws {
        let completed = Set(ReviewMatchCatalog.rounds.flatMap(\.pairs).compactMap(\.requiredLessonID))
        let boards = ReviewMatchCatalog.unlocked(completed: completed)
        XCTAssertEqual(boards.count, 5)
        for board in boards {
            for pair in board.pairs {
                let lessonID = try XCTUnwrap(pair.requiredLessonID)
                XCTAssertTrue(completed.contains(lessonID), pair.id)
            }
        }
    }

    func testReviewCapsAtFiveBoardsEvenWhenMoreAreReady() {
        let completed = Set(ReviewMatchCatalog.rounds.flatMap(\.pairs).compactMap(\.requiredLessonID))
        XCTAssertGreaterThan(ReviewMatchCatalog.rounds.count, ReviewMatchCatalog.maximumRounds)
        XCTAssertEqual(
            ReviewMatchCatalog.unlocked(completed: completed).count,
            ReviewMatchCatalog.maximumRounds
        )
    }

    func testReviewMixedBoardUsesOnlyUnlockedLeftovers() {
        let core = Set(ReviewMatchCatalog.core.pairs.compactMap(\.requiredLessonID))
        let collections = Set(ReviewMatchCatalog.collections.pairs.compactMap(\.requiredLessonID))
        let fourCore = Set(core.dropLast())
        let ready = fourCore.union(collections)
        let boards = ReviewMatchCatalog.unlocked(completed: ready)
        XCTAssertEqual(boards.first?.id, "review.collections")
        XCTAssertGreaterThan(boards.count, 1, "partial learned boards should not be discarded")
        for pair in boards.flatMap(\.pairs) {
            XCTAssertNotEqual(pair.requiredLessonID, core.subtracting(fourCore).first)
        }
    }

    func testEveryReviewLessonIsATeachingOrChallengeLesson() {
        for pair in ReviewMatchCatalog.allPairs {
            guard let id = pair.requiredLessonID else {
                return XCTFail(pair.id)
            }
            XCTAssertNotNil(GoCourseCatalog.lesson(id: id), id)
        }
    }

    func testReviewNeverShowsFewerThanThreePairsOrUnlearnedContent() {
        for lesson in GoCourseCatalog.lessons {
            let boards = ReviewMatchCatalog.unlocked(completed: [lesson.id])
            XCTAssertTrue(boards.allSatisfy { $0.pairs.count >= 3 })
            XCTAssertTrue(boards.flatMap(\.pairs).allSatisfy { $0.requiredLessonID == lesson.id })
            if !boards.isEmpty { XCTAssertGreaterThanOrEqual(boards.count, 3) }
        }
    }

    func testFirstFiveTeachingLessonsFillReviewWithoutDoingHiddenChallenges() {
        let completed = Set(GoCourseCatalog.teachingLessons.prefix(5).map(\.id))
        let pairs = ReviewMatchCatalog.unlocked(completed: completed).flatMap(\.pairs)
        XCTAssertGreaterThanOrEqual(pairs.count, 5)
        XCTAssertTrue(pairs.allSatisfy { completed.contains($0.requiredLessonID ?? "") })
    }

    func testShortDeclarationAloneOffersThreeKnownPairsAndThreeRounds() throws {
        let lesson = try XCTUnwrap(GoCourseCatalog.lesson(id: "core.short-declaration"))
        let boards = ReviewMatchCatalog.unlocked(completed: [lesson.id])
        XCTAssertEqual(boards.count, 3)
        for board in boards {
            XCTAssertGreaterThanOrEqual(board.pairs.count, 3)
            XCTAssertEqual(Set(board.pairs.map(\.answer)).count, board.pairs.count)
        }
    }

    func testGeneratedBoardsHaveDistinctAnswersAndRespectTileBudget() {
        for unit in GoCourseCatalog.units {
            for board in ReviewMatchCatalog.unlocked(completed: Set(unit.lessons.map(\.id))) {
                XCTAssertEqual(Set(board.pairs.map(\.answer)).count, board.pairs.count, board.id)
                XCTAssertLessThanOrEqual(board.pairs.count, ReviewMatchCatalog.pairsPerRound)
                XCTAssertFalse(board.pairs.isEmpty)
            }
        }
    }

    func testEveryCorrectlyAnsweredConceptCanFillMatching() {
        for tag in GoConcept.all {
            let boards = ReviewMatchCatalog.unlocked(completed: [], confirmedConcepts: [tag])
            // An early concept with fewer than three authored facts waits for
            // more learned material rather than inventing distractor pairs.
            XCTAssertTrue(boards.allSatisfy { $0.pairs.count >= 3 }, tag)
            XCTAssertTrue(boards.flatMap(\.pairs).allSatisfy { $0.conceptTag == tag }, tag)
        }
    }
}
