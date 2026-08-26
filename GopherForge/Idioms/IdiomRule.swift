import Foundation

/// A single deterministic idiom rule.
///
/// Rules are data, not scattered conditionals, so the catalogue can be read in
/// one place, tested one rule at a time, and shown to the user as the coach's
/// full vocabulary rather than as unexplained opinions.
struct IdiomRule: Identifiable, Sendable {
    let id: String
    let conceptTag: String
    let title: String
    let explanation: String
    let confidence: IdiomFinding.Confidence
    /// Returns a finding when the rule recognises its shape on this line.
    let match: @Sendable (_ line: String, _ context: IdiomRuleContext) -> IdiomRuleMatch?
}

/// What a rule can see besides the line itself.
struct IdiomRuleContext: Sendable {
    let fileName: String
    let lineNumber: Int
    let previousLine: String
    let nextLine: String
    let indentation: String
    /// True inside a function body, so declaration-level rules do not fire on
    /// package-level code and vice versa.
    let isInsideFunction: Bool
}

struct IdiomRuleMatch: Sendable {
    let suggestedReplacement: String?

    static let flagOnly = IdiomRuleMatch(suggestedReplacement: nil)

    static func replace(with replacement: String) -> IdiomRuleMatch {
        IdiomRuleMatch(suggestedReplacement: replacement)
    }
}
