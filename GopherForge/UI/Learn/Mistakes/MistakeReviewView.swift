import SwiftUI

struct MistakeReviewView: View {
    @Environment(LearnProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var session: MistakeReviewSession
    @State private var isSaving = false
    @State private var saveError: String?
    let correcting: Bool

    init(questions: [MistakeReviewQuestion], correcting: Bool) {
        _session = State(initialValue: MistakeReviewSession(questions: questions))
        self.correcting = correcting
    }

    var body: some View {
        Group {
            if let item = session.current {
                question(item.question)
                    .id(item.id)
            } else {
                completion
            }
        }
        .navigationTitle(correcting ? "Work on mistakes" : "Knowledge check")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            if !session.isFinished {
                VStack(spacing: 6) {
                    Text("Question \(session.index + 1) of \(session.questions.count)")
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("mistakes.progress")
                    ProgressView(value: session.progress)
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(.bar)
            }
        }
    }

    private func question(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(LearningProse.inline(question.prompt)).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mistakes.question")
                if !question.code.isEmpty { CodeBlock(title: "Go", code: question.code) }
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, text in
                    Button { choose(index) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: session.rejectedOptions.contains(index) ? "xmark.circle.fill" : "circle")
                            Text(LearningProse.inline(text))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(session.rejectedOptions.contains(index) ? Color.red : Color.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || session.rejectedOptions.contains(index))
                    .accessibilityIdentifier("mistakes.option.\(index)")
                }
                if !session.rejectedOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Why this is not right", systemImage: "lightbulb")
                            .font(.subheadline.bold())
                        LearningProse(text: question.explanation)
                        Text("Choose the correct answer to continue.")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(16)
                    .background(GopherForgeTheme.aqua.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("mistakes.explanation")
                }
                if let saveError {
                    Text(saveError).foregroundStyle(.red).font(.footnote)
                }
                if isSaving { ProgressView("Saving answer…") }
            }
            .padding(18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48))
                .foregroundStyle(GopherForgeTheme.aqua)
            Text(correcting ? "Mistakes worked through" : "Knowledge check complete").font(.title2.bold())
            Text("\(session.questions.count) concept\(session.questions.count == 1 ? "" : "s") checked. Your answers are saved.")
                .foregroundStyle(.secondary)
            if session.wrongAttempts > 0 {
                Text("\(session.wrongAttempts) wrong answer\(session.wrongAttempts == 1 ? "" : "s") explained and corrected.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("mistakes.done")
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mistakes.complete")
    }

    private func choose(_ option: Int) {
        guard !isSaving, let attempt = session.attempt(for: option) else { return }
        isSaving = true
        saveError = nil
        Task {
            do {
                try await progress.record(attempt)
                withAnimation(.easeOut(duration: 0.15)) { session.advance(after: option) }
            } catch {
                saveError = "Could not save your answer. Please try again."
            }
            isSaving = false
        }
    }
}
