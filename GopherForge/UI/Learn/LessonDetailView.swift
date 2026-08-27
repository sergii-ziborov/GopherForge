import SwiftUI

/// One lesson: explanation, the task, and the verdict from the real toolchain.
struct LessonDetailView: View {
    let lesson: Lesson

    @State private var model: LessonModel

    init(lesson: Lesson) {
        self.lesson = lesson
        _model = State(initialValue: LessonModel(lesson: lesson))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                explanation
                taskSection

                if lesson.requiresCompiler, !model.canCheck, !model.isChecking {
                    Label(model.toolchainDetail, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let result = model.result {
                    LessonVerdictView(result: result, solution: lesson.idiomaticSolution)
                }
            }
            .padding(16)
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if lesson.requiresCompiler {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.check() }
                    } label: {
                        if model.isChecking {
                            ProgressView()
                        } else {
                            Label("Check", systemImage: "checkmark.diamond")
                        }
                    }
                    .disabled(!model.canCheck)
                    .accessibilityIdentifier(AccessibilityID.lessonCheck)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lesson.objective)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if !lesson.conceptTags.isEmpty {
                Text(lesson.conceptTags.joined(separator: " · "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var explanation: some View {
        Text(lesson.explanation)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var taskSection: some View {
        switch lesson.task {
        case let .guidedTyping(target):
            CodeBlock(title: "Type this until it is automatic", code: target)
        case let .fillGaps(template, blanks):
            VStack(alignment: .leading, spacing: 8) {
                CodeBlock(title: "Fill the gaps", code: template)
                Text("Missing: \(blanks.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .predict(source, question, answer):
            VStack(alignment: .leading, spacing: 8) {
                CodeBlock(title: "Predict the output", code: source)
                Text(question).font(.callout.weight(.medium))
                DisclosureGroup("Show the answer") {
                    Text(answer)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .compile:
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit until the hidden test passes")
                    .font(.callout.weight(.medium))
                SyntaxCodeEditor(
                    text: $model.editorText,
                    fileKind: .go,
                    fontSize: 13
                )
                .frame(height: 320)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

/// What the toolchain said, and only then the idiomatic answer.
struct LessonVerdictView: View {
    let result: CompilationResult
    let solution: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: result.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill")
                    .foregroundStyle(GopherForgeTheme.statusColor(succeeded: result.succeeded))
                Text(result.detail).font(.callout)
            }

            ForEach(result.diagnostics) { diagnostic in
                Text(diagnostic.rendered)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if result.succeeded, let solution {
                CodeBlock(title: "How Go would usually write it", code: solution)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
