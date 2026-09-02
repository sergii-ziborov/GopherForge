import Foundation
import Observation

/// One sitting of the bug hunt.
///
/// A guess is committed and cannot be taken back, because the value of the game
/// is entirely in the moment before the guess. Undo would turn it into a
/// search.
@MainActor
@Observable
final class SpotTheBugSession {
    /// What happened on a round, kept so the summary can say more than a score.
    struct Answer: Identifiable, Equatable {
        let round: SpotTheBugRound
        let chosenLine: Int
        var id: String { round.id }
        var isCorrect: Bool { round.isCorrect(chosenLine) }
    }

    let rounds: [SpotTheBugRound]
    private(set) var index = 0
    private(set) var answers: [Answer] = []

    init(rounds: [SpotTheBugRound]) {
        self.rounds = rounds
    }

    var round: SpotTheBugRound? {
        rounds.indices.contains(index) ? rounds[index] : nil
    }

    var isFinished: Bool { index >= rounds.count }

    var correctCount: Int { answers.count(where: \.isCorrect) }

    /// The answer for the round on screen, or nil while it is still open.
    var currentAnswer: Answer? {
        guard let round else { return nil }
        return answers.first { $0.round.id == round.id }
    }

    var hasAnswered: Bool { currentAnswer != nil }

    func choose(line: Int) {
        guard let round, !hasAnswered else { return }
        answers.append(Answer(round: round, chosenLine: line))
    }

    func advance() {
        guard hasAnswered else { return }
        index += 1
    }

    /// The concepts the misses were about, in the vocabulary review speaks.
    ///
    /// Only the misses: a round somebody got right is not evidence they need
    /// practice, and padding the review queue with things people know is how a
    /// queue stops being worth opening.
    var missedConceptTags: [String] {
        answers.filter { !$0.isCorrect }.map(\.round.conceptTag)
    }

    /// Reported as a drill result, because that is what it is to everything
    /// downstream: a set of attempts with the concepts behind the misses. The
    /// badges and the review queue already read this shape, and inventing a
    /// second one would mean teaching both of them about it.
    var result: MatchingDrillResult {
        MatchingDrillResult(
            drillID: "spot-the-bug",
            completedAt: Date(),
            mistakes: answers.count - correctCount,
            mistakenConcepts: missedConceptTags
        )
    }
}
