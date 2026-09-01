import SwiftUI

/// One lesson: explanation, the task, and the verdict from the real toolchain.
struct LessonDetailView: View {
    let lesson: Lesson

    @State private var model: LessonModel
    @Environment(LearnProgress.self) private var progress

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

                completion
            }
            .padding(16)
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadProgress() }
        .toolbar {
            // The completion control lives here because a compile lesson puts a
            // text view between the explanation and the bottom of the page, and
            // a swipe over a text view scrolls the text rather than the page —
            // which left the button underneath it unreachable. A toolbar item
            // is reachable whatever is on screen.
            ToolbarItem(placement: .topBarTrailing) {
                completionToggle
            }

            if lesson.requiresCompiler {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await model.check()
                            // The course is showing this lesson's state too, and
                            // a pass it never hears about is a tick nobody sees.
                            await progress.refresh()
                        }
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

    /// Whether this is done, and the way to say so.
    ///
    /// Every lesson can be ticked. It used to be that only a lesson with
    /// nothing to run could, which left four of the seven units with no way to
    /// record progress at all — their lessons are all compile lessons, and a
    /// learner who had done the work elsewhere could not say so.
    ///
    /// A compile lesson still asks for Check first, and the app records which
    /// of the two happened rather than flattening them into one tick.
    @ViewBuilder
    private var completion: some View {
        if model.isCompleted {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    model.isCompilerVerified ? "Passed the compiler" : "Marked done",
                    systemImage: model.isCompilerVerified
                        ? "checkmark.seal.fill"
                        : "checkmark.circle.fill"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(model.isCompilerVerified ? Color.green : GopherForgeTheme.slate)

                if !model.isCompilerVerified, lesson.isJudgedByCompiler {
                    Text("You said so — the hidden test has not run. Press Check to "
                        + "have it judged, or use the tick above to take this back.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                (model.isCompilerVerified ? Color.green : GopherForgeTheme.slate).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12)
            )
            // One element, so the identifier belongs to the card rather than
            // being inherited by every label inside it — which made a search
            // for it ambiguous, and made the card three things to VoiceOver.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.lessonCompleted)
        } else {
            VStack(spacing: 8) {
                if lesson.isJudgedByCompiler {
                    Text("Press Check to have the hidden test judge this, or mark it "
                        + "done if you have already worked through it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Secondary where the compiler is the better judge, so Check
                // stays the obvious thing to press; prominent where there is
                // nothing to run and this is the only way to finish.
                // The identifier goes on each button rather than on a wrapper:
                // a modifier on a Group lands on the container, and the button
                // underneath keeps no identifier at all.
                if lesson.isJudgedByCompiler {
                    Button(action: markDone) { markLabel }
                        .buttonStyle(.bordered)
                } else {
                    Button(action: markDone) { markLabel }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    /// Done or not, in one tap, from anywhere on the page.
    ///
    /// Tapping an unmarked lesson says you have done it. Tapping one you marked
    /// yourself takes it back. A pass the compiler witnessed cannot be undone,
    /// so it is shown and not offered as a toggle.
    @ViewBuilder
    private var completionToggle: some View {
        if model.isCompleted, model.isCompilerVerified {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Passed the compiler")
                .accessibilityIdentifier(AccessibilityID.lessonVerified)
        } else if model.isCompleted {
            Button {
                Task {
                    await model.clearCompletion()
                    await progress.refresh()
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(GopherForgeTheme.slate)
            }
            .accessibilityLabel("Marked done. Tap to undo.")
            .accessibilityIdentifier(AccessibilityID.lessonUncomplete)
        } else {
            Button(action: markDone) {
                Image(systemName: "circle")
            }
            .accessibilityLabel("Mark as completed")
            .accessibilityIdentifier(AccessibilityID.lessonComplete)
        }
    }

    private var markLabel: some View {
        Label("Mark as completed", systemImage: "checkmark.circle")
            .frame(maxWidth: .infinity)
    }

    private func markDone() {
        Task {
            await model.markCompleted()
            await progress.refresh()
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
