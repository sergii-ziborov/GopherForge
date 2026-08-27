import SwiftUI

/// One question at a time, answered and then explained.
///
/// The explanation arrives at the moment someone is most ready to read it —
/// right after committing to an answer — rather than at the end, when the
/// question has already been forgotten. Right or wrong, it is shown either way:
/// knowing why a right answer is right is the part that transfers.
struct QuizView: View {
    @State private var session: QuizSession
    @State private var didRecord = false
    private let onFinish: (QuizResult) -> Void

    init(quiz: Quiz, onFinish: @escaping (QuizResult) -> Void = { _ in }) {
        _session = State(initialValue: QuizSession(quiz: quiz))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            QuizProgressBar(
                progress: session.progress,
                answered: session.answers.count,
                total: session.quiz.questions.count,
                correct: session.correctCount
            )

            if let question = session.currentQuestion {
                QuestionCard(
                    question: question,
                    chosenIndex: session.chosenIndex,
                    onChoose: session.choose
                )
                QuizFooter(
                    chosenIndex: session.chosenIndex,
                    question: question,
                    isLast: session.index == session.quiz.questions.count - 1,
                    onContinue: session.advance
                )
            } else {
                QuizSummaryView(
                    correct: session.correctCount,
                    total: session.quiz.questions.count,
                    passed: session.isPassed,
                    mistakenConcepts: session.mistakenConcepts,
                    onRestart: restart
                )
            }
        }
        .navigationTitle(session.quiz.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onChange(of: session.isFinished) { _, finished in
            guard finished, !didRecord else { return }
            didRecord = true
            onFinish(session.result())
        }
    }

    private func restart() {
        session.restart()
        didRecord = false
    }
}

/// How far through, and how it is going.
private struct QuizProgressBar: View {
    let progress: Double
    let answered: Int
    let total: Int
    let correct: Int

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [GopherForgeTheme.anvil, GopherForgeTheme.ember],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(0, geometry.size.width * progress))
                        .animation(.easeOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(answered) of \(total)")
                Spacer()
                Label("\(correct)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityIdentifier(AccessibilityID.quizProgress)
    }
}

/// The bar across the bottom: the explanation, then the way onward.
private struct QuizFooter: View {
    let chosenIndex: Int?
    let question: QuizQuestion
    let isLast: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let chosenIndex {
                let right = question.isCorrect(chosenIndex)
                Label(
                    right ? "Right" : "Not quite — \(question.correctAnswer)",
                    systemImage: right ? "checkmark.seal.fill" : "xmark.seal.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(right ? Color.green : Color.orange)

                Text(question.explanation)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)

                Button(isLast ? "See the result" : "Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityID.quizContinue)
            } else {
                Text("Choose an answer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.bar)
        .animation(.easeOut(duration: 0.2), value: chosenIndex)
    }
}
