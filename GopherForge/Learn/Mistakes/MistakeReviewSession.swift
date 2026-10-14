import Foundation
import Observation

@MainActor
@Observable
final class MistakeReviewSession {
    let questions: [MistakeReviewQuestion]
    private(set) var index = 0
    private(set) var rejectedOptions: Set<Int> = []
    private(set) var wrongAttempts = 0

    init(questions: [MistakeReviewQuestion]) { self.questions = questions }

    var current: MistakeReviewQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    var isFinished: Bool { index == questions.count }
    var progress: Double { questions.isEmpty ? 0 : Double(index) / Double(questions.count) }

    func attempt(for option: Int) -> MistakeReviewAttempt? {
        guard let item = current, item.question.options.indices.contains(option),
              !rejectedOptions.contains(option) else { return nil }
        return MistakeReviewAttempt(
            questionID: item.id, conceptTag: item.question.conceptTag,
            succeeded: item.question.isCorrect(option)
        )
    }

    /// Called after persistence succeeds. Wrong answers stay on the question;
    /// correct answers move forward immediately, without a manual Done tick.
    func advance(after option: Int) {
        guard let attempt = attempt(for: option) else { return }
        if attempt.succeeded {
            index += 1
            rejectedOptions.removeAll()
        } else {
            wrongAttempts += 1
            rejectedOptions.insert(option)
        }
    }
}
