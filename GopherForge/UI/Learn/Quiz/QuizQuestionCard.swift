import SwiftUI

/// The question and its options.
///
/// Options are full-width rows rather than a list of radio buttons: on a phone
/// the whole row is the target, and a tap that misses is worse than a wrong
/// answer because it teaches nothing.
struct QuestionCard: View {
    let question: QuizQuestion
    let chosenIndex: Int?
    let onChoose: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(question.prompt)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if !question.code.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(question.code)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }

                VStack(spacing: 8) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        QuizOptionRow(
                            text: option,
                            state: state(for: index),
                            action: { onChoose(index) }
                        )
                        .accessibilityIdentifier("quiz.option.\(index)")
                    }
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier(AccessibilityID.quizQuestion)
    }

    private func state(for index: Int) -> QuizOptionRow.State {
        guard let chosenIndex else { return .unanswered }
        if index == question.correctIndex { return .correct }
        if index == chosenIndex { return .wrong }
        return .dimmed
    }
}

/// One option.
struct QuizOptionRow: View {
    enum State {
        case unanswered
        case correct
        case wrong
        /// Neither chosen nor right, once the question is answered.
        case dimmed
    }

    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .font(.body)
                Text(text)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(state == .unanswered ? 0.25 : 0.9), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(state != .unanswered)
        .opacity(state == .dimmed ? 0.45 : 1)
        .animation(.easeOut(duration: 0.2), value: state)
    }

    private var symbol: String {
        switch state {
        case .unanswered, .dimmed: "circle"
        case .correct: "checkmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .unanswered, .dimmed: .secondary
        case .correct: .green
        case .wrong: .orange
        }
    }

    private var background: Color {
        switch state {
        case .unanswered, .dimmed: Color(.secondarySystemGroupedBackground)
        case .correct: Color.green.opacity(0.14)
        case .wrong: Color.orange.opacity(0.14)
        }
    }
}
