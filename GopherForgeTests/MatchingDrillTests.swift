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
        for drill in MatchingDrillCatalog.drills {
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
    }

    func testDrillIdentifiersAndPairsAreUnique() {
        let drillIDs = MatchingDrillCatalog.drills.map(\.id)
        XCTAssertEqual(Set(drillIDs).count, drillIDs.count)

        let pairIDs = MatchingDrillCatalog.drills.flatMap { $0.pairs.map(\.id) }
        XCTAssertEqual(Set(pairIDs).count, pairIDs.count, "pair ids must be unique across drills")
    }

    /// A drill's answers have to be distinct, or two tiles are both correct for
    /// one prompt and the board calls one of them wrong.
    func testNoDrillRepeatsAnAnswer() {
        for drill in MatchingDrillCatalog.drills {
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
        for drill in MatchingDrillCatalog.drills {
            for pair in drill.pairs {
                XCTAssertTrue(
                    known.contains(pair.conceptTag),
                    "\(pair.id) tags \(pair.conceptTag), which no lesson teaches"
                )
            }
        }
    }
}
