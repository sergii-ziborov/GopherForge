import Foundation
import Observation

/// One run through a quiz.
///
/// One question at a time, answered and then explained before the next appears.
/// A quiz that shows every question at once invites scanning for the pattern
/// rather than reading; a quiz that hides the explanation until the end teaches
/// nothing at the moment someone is most ready to learn it.
@MainActor
@Observable
final class QuizSession {
    struct Answer: Equatable {
        let questionID: String
        let chosenIndex: Int
        let wasCorrect: Bool
    }

    let quiz: Quiz
    private(set) var index = 0
    private(set) var answers: [Answer] = []
    /// The option chosen for the question on screen, or nil while it is still
    /// unanswered. Its presence is what switches the view to its explanation.
    private(set) var chosenIndex: Int?

    init(quiz: Quiz) {
        self.quiz = quiz
    }

    var currentQuestion: QuizQuestion? {
        index < quiz.questions.count ? quiz.questions[index] : nil
    }

    var isFinished: Bool { index >= quiz.questions.count }
    var correctCount: Int { answers.count(where: \.wasCorrect) }
    var isPassed: Bool { quiz.passed(correct: correctCount) }

    /// Answered so far, out of the whole quiz.
    var progress: Double {
        quiz.questions.isEmpty ? 0 : Double(answers.count) / Double(quiz.questions.count)
    }

    /// Concepts got wrong, for the review queue. The same tags a compiler
    /// mistake produces, so both end up in one place.
    var mistakenConcepts: [String] {
        let wrong = answers.filter { !$0.wasCorrect }.map(\.questionID)
        return Array(
            Set(quiz.questions.filter { wrong.contains($0.id) }.map(\.conceptTag))
        ).sorted()
    }

    // MARK: - Answering

    /// Records an answer. Answering twice does nothing: the second tap is
    /// almost always a mis-tap on the explanation that just appeared.
    func choose(_ optionIndex: Int) {
        guard chosenIndex == nil, let question = currentQuestion else { return }
        chosenIndex = optionIndex
        answers.append(
            Answer(
                questionID: question.id,
                chosenIndex: optionIndex,
                wasCorrect: question.isCorrect(optionIndex)
            )
        )
    }

    func advance() {
        guard chosenIndex != nil else { return }
        chosenIndex = nil
        index += 1
    }

    func restart() {
        index = 0
        answers = []
        chosenIndex = nil
    }

    func result() -> QuizResult {
        QuizResult(
            unitID: quiz.unitID,
            completedAt: Date(),
            correct: correctCount,
            total: quiz.questions.count,
            mistakenConcepts: mistakenConcepts
        )
    }
}

/// A finished quiz, recorded so review and achievements can both read it.
struct QuizResult: Codable, Equatable, Sendable {
    let unitID: String
    let completedAt: Date
    let correct: Int
    let total: Int
    let mistakenConcepts: [String]

    var isPerfect: Bool { total > 0 && correct == total }
    var passed: Bool {
        total > 0 && Double(correct) / Double(total) >= Quiz.passingFraction
    }
}
