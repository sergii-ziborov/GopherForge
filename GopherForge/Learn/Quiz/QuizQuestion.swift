import Foundation

/// One question with one right answer.
///
/// Four options rather than two, because a coin flip is not evidence of
/// anything, and an explanation on every question rather than only the wrong
/// ones: knowing *why* the right answer is right is the part that transfers.
struct QuizQuestion: Identifiable, Equatable, Sendable {
    let id: String
    /// The question, in plain words.
    let prompt: String
    /// Go source the question is about, shown monospaced above the options.
    /// Empty when the question needs no code.
    let code: String
    let options: [String]
    /// Index into `options`.
    let correctIndex: Int
    /// Shown after answering, right or wrong.
    let explanation: String
    /// The same vocabulary the compiler and the review scheduler use, so a
    /// wrong answer feeds the same queue a failed build does.
    let conceptTag: String

    var correctAnswer: String { options[correctIndex] }

    func isCorrect(_ index: Int) -> Bool { index == correctIndex }
}

/// The questions that close a unit.
struct Quiz: Identifiable, Equatable, Sendable {
    /// Enough to be evidence, few enough to finish in one sitting.
    static let maximumQuestions = 8
    /// Long options are unreadable on a phone at a glance, and a glance is what
    /// a multiple choice is for.
    static let maximumOptionCharacters = 62

    let unitID: String
    let title: String
    let questions: [QuizQuestion]

    var id: String { unitID }

    /// The share of questions that must be right to count as passed. Four in
    /// five: high enough to mean something, low enough that one slip is not a
    /// failure.
    static let passingFraction = 0.8

    func passed(correct: Int) -> Bool {
        guard !questions.isEmpty else { return false }
        return Double(correct) / Double(questions.count) >= Self.passingFraction
    }
}
