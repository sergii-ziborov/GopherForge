import Foundation

/// One idiom suggestion about a specific line.
///
/// A finding is never a correctness claim. The compiler and the type checker
/// decide whether code is valid; this layer only recognises shapes that Go
/// developers have agreed read badly, and every finding carries the reason so
/// the user can disagree with it.
struct IdiomFinding: Identifiable, Equatable, Sendable {
    enum Confidence: String, Sendable {
        /// The shape is unambiguous, for example a parameter list that puts
        /// `context.Context` second.
        case certain
        /// The shape is a strong hint but depends on intent the analyzer
        /// cannot see.
        case likely
    }

    let id = UUID()
    let ruleID: String
    let conceptTag: String
    let title: String
    let explanation: String
    let fileName: String
    let line: Int
    let confidence: Confidence
    /// The replacement the repair action would apply, when the rule can
    /// produce one safely.
    let suggestedReplacement: String?

    var isAutoRepairable: Bool { suggestedReplacement != nil }
}

/// How the user answered a suggestion. Both answers are useful: an accepted
/// suggestion is a learning signal, and a rejected one keeps the coach from
/// nagging about a deliberate choice.
enum IdiomResponse: String, Sendable {
    case accepted
    case rejected
    case ignored
}
