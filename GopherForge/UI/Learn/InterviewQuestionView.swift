import SwiftUI

/// An interview question, answered the way one actually is: out loud, first,
/// and only then compared with a strong answer.
///
/// The model answer is behind a disclosure for the same reason the lab's
/// prediction is. A question with its answer beside it is reading; a question
/// you have to sit with for ten seconds is practice.
struct InterviewQuestionView: View {
    let questions: [InterviewQuestion]

    @State private var index = 0
    @State private var isAnswerShown = false

    private var question: InterviewQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let question {
                    header(question)

                    Text(question.prompt)
                        .font(.title3.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)

                    if !question.code.isEmpty {
                        CodeBlock(title: "", code: question.code)
                    }

                    if isAnswerShown {
                        answer(question)
                        trap(question)
                    } else {
                        prompt
                    }

                    navigation
                }
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Interview prep")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.interviewBoard)
    }

    private func header(_ question: InterviewQuestion) -> some View {
        HStack {
            Text("QUESTION \(index + 1) OF \(questions.count)")
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(question.conceptTag)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private var prompt: some View {
        Button {
            withAnimation { isAnswerShown = true }
        } label: {
            Label("Answer it out loud, then show a strong answer", systemImage: "mic")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(AccessibilityID.interviewReveal)
    }

    private func answer(_ question: InterviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What a strong answer covers", systemImage: "checkmark.seal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GopherForgeTheme.accent)
                .textCase(.uppercase)

            ForEach(Array(question.answerPoints.enumerated()), id: \.offset) { number, point in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(number + 1)")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(GopherForgeTheme.accentSolid, in: Circle())
                    Text(point)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GopherForgeTheme.accentWash(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func trap(_ question: InterviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("The answer that sounds right", systemImage: "exclamationmark.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GopherForgeTheme.berry)
                .textCase(.uppercase)
            Text(question.trap)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GopherForgeTheme.berry.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            Button {
                move(by: -1)
            } label: {
                Label("Back", systemImage: "chevron.left").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(index == 0)

            Button {
                move(by: 1)
            } label: {
                Label("Next", systemImage: "chevron.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(index + 1 >= questions.count)
            .accessibilityIdentifier(AccessibilityID.interviewNext)
        }
    }

    private func move(by offset: Int) {
        let next = index + offset
        guard questions.indices.contains(next) else { return }
        index = next
        // Closed again for the new question: the point is the pause before the
        // answer, and carrying "shown" across would remove it.
        isAnswerShown = false
    }
}
