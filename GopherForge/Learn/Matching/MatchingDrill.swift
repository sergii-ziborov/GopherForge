import Foundation

/// One pair to connect: a term on the left, what it means on the right.
struct MatchingPair: Identifiable, Equatable, Sendable {
    let id: String
    /// The left tile. Short by design — a term, a signature, a line of Go.
    let prompt: String
    /// The right tile. What it means, or what it does.
    let answer: String
    /// The concept this pair exercises, in the same vocabulary the compiler
    /// and the review scheduler use, so a drill mistake reaches the same queue
    /// as a compiler mistake.
    let conceptTag: String
}

/// A set of pairs shown together.
///
/// Kept small on purpose. Twelve tiles on a phone is already a full screen,
/// and a drill that needs scrolling stops being a glance-and-match exercise.
struct MatchingDrill: Identifiable, Equatable, Sendable {
    /// The most pairs one drill may hold. Enforced by a test rather than by
    /// hope, because the board's whole promise is that nothing jumps or hides.
    static let maximumPairs = 6

    /// Tile text budgets. The board gives every tile the same height, so text
    /// that cannot fit would have to shrink or truncate — either of which makes
    /// one tile look different from its neighbours.
    static let maximumPromptCharacters = 34
    static let maximumAnswerCharacters = 58

    let id: String
    let title: String
    let subtitle: String
    /// The course unit this belongs to, so it can be offered where it is
    /// relevant rather than only from a list of drills.
    let unitID: String
    let pairs: [MatchingPair]

    var conceptTags: [String] {
        Array(Set(pairs.map(\.conceptTag))).sorted()
    }
}
