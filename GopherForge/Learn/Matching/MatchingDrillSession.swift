import Foundation
import Observation

/// One run of a matching drill.
///
/// The board never removes a tile. A matched pair goes quiet and stays where it
/// is, because tiles that disappear make the rows below them jump, and the
/// whole point of a drill you play with your thumb is that the target does not
/// move while you are reaching for it.
@MainActor
@Observable
final class MatchingDrillSession {
    enum TileSide: Sendable {
        case prompt
        case answer
    }

    enum TileState: Sendable, Equatable {
        case idle
        case selected
        case matched
        /// Briefly, after a wrong connection, on both tiles involved.
        case rejected
    }

    struct Tile: Identifiable, Equatable, Sendable {
        let id: String
        let pairID: String
        let side: TileSide
        let text: String
    }

    let drill: MatchingDrill
    private(set) var prompts: [Tile] = []
    private(set) var answers: [Tile] = []
    private(set) var matchedPairs: Set<String> = []
    private(set) var mistakes = 0
    /// Concept tags the learner connected wrongly, which is what the review
    /// queue is interested in.
    private(set) var mistakenConcepts: Set<String> = []

    private(set) var selectedPromptID: String?
    private(set) var selectedAnswerID: String?
    private(set) var rejectedPairIDs: Set<String> = []

    var isComplete: Bool {
        matchedPairs.count == drill.pairs.count
    }

    var progress: Double {
        drill.pairs.isEmpty ? 0 : Double(matchedPairs.count) / Double(drill.pairs.count)
    }

    /// A perfect run is the achievement-worthy one: every pair connected with
    /// no wrong connection at all.
    var isPerfect: Bool {
        isComplete && mistakes == 0
    }

    /// `shuffle` is injected so a test can pin the order. Nothing about the
    /// rules should depend on it, and a test that cannot fix the layout cannot
    /// prove that.
    init(drill: MatchingDrill, shuffle: ([Tile]) -> [Tile] = { $0.shuffled() }) {
        self.drill = drill
        prompts = shuffle(drill.pairs.map {
            Tile(id: "\($0.id)#prompt", pairID: $0.id, side: .prompt, text: $0.prompt)
        })
        answers = shuffle(drill.pairs.map {
            Tile(id: "\($0.id)#answer", pairID: $0.id, side: .answer, text: $0.answer)
        })
    }

    // MARK: - Playing

    func state(of tile: Tile) -> TileState {
        if matchedPairs.contains(tile.pairID) { return .matched }
        if rejectedPairIDs.contains(tile.pairID) { return .rejected }
        if tile.id == selectedPromptID || tile.id == selectedAnswerID { return .selected }
        return .idle
    }

    /// Taps a tile. Tapping a matched one does nothing; tapping a selected one
    /// deselects it, so a mis-tap costs nothing.
    func select(_ tile: Tile) {
        guard !matchedPairs.contains(tile.pairID) else { return }
        rejectedPairIDs.removeAll()

        switch tile.side {
        case .prompt:
            selectedPromptID = selectedPromptID == tile.id ? nil : tile.id
        case .answer:
            selectedAnswerID = selectedAnswerID == tile.id ? nil : tile.id
        }

        resolveIfBothChosen()
    }

    func clearRejection() {
        rejectedPairIDs.removeAll()
    }

    private func resolveIfBothChosen() {
        guard let promptID = selectedPromptID,
              let answerID = selectedAnswerID,
              let prompt = prompts.first(where: { $0.id == promptID }),
              let answer = answers.first(where: { $0.id == answerID })
        else {
            return
        }

        selectedPromptID = nil
        selectedAnswerID = nil

        if prompt.pairID == answer.pairID {
            matchedPairs.insert(prompt.pairID)
            return
        }

        mistakes += 1
        rejectedPairIDs = [prompt.pairID, answer.pairID]
        for pairID in [prompt.pairID, answer.pairID] {
            if let tag = drill.pairs.first(where: { $0.id == pairID })?.conceptTag {
                mistakenConcepts.insert(tag)
            }
        }
    }

    /// What the drill did, in the form the rest of the app already understands.
    func result() -> MatchingDrillResult {
        MatchingDrillResult(
            drillID: drill.id,
            completedAt: Date(),
            mistakes: mistakes,
            mistakenConcepts: mistakenConcepts.sorted()
        )
    }
}

/// A finished drill, recorded so review and achievements can both read it.
struct MatchingDrillResult: Codable, Equatable, Sendable {
    let drillID: String
    let completedAt: Date
    let mistakes: Int
    let mistakenConcepts: [String]

    var isPerfect: Bool { mistakes == 0 }
}
