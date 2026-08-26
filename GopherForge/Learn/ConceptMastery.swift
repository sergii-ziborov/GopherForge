import Foundation

/// What the app believes about one concept for one learner.
struct ConceptMastery: Codable, Equatable, Identifiable, Sendable {
    let conceptTag: String
    var successes: Int
    var mistakes: Int
    var lastSeenAt: Date?
    var lastMistakeAt: Date?

    var id: String { conceptTag }

    /// Between 0 and 1. Deliberately pessimistic after a recent mistake: the
    /// point of review is to revisit what is shaky, not to reward streaks.
    var strength: Double {
        let total = successes + mistakes
        guard total > 0 else { return 0 }
        let ratio = Double(successes) / Double(total)
        guard let lastMistakeAt else { return ratio }
        let daysSinceMistake = Date().timeIntervalSince(lastMistakeAt) / 86_400
        let recencyPenalty = max(0, 1 - daysSinceMistake / 7) * 0.4
        return max(0, ratio - recencyPenalty)
    }

    mutating func record(succeeded: Bool, at date: Date = Date()) {
        if succeeded {
            successes += 1
        } else {
            mistakes += 1
            lastMistakeAt = date
        }
        lastSeenAt = date
    }

    static func empty(_ conceptTag: String) -> ConceptMastery {
        ConceptMastery(
            conceptTag: conceptTag,
            successes: 0,
            mistakes: 0,
            lastSeenAt: nil,
            lastMistakeAt: nil
        )
    }
}
