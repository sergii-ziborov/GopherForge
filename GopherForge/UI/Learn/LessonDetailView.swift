import SwiftUI

/// One lesson: where it sits, what it teaches, the task, the verdict from the
/// real toolchain, and the way onward.
///
/// It used to be a single column of equally-weighted paragraphs that ended in a
/// tick and nothing else — no unit, no position, no next lesson, and two
/// different controls for "done" with no explanation of how they differed.
struct LessonDetailView: View {
    let lesson: Lesson

    @State private var model: LessonModel
    @Environment(LearnProgress.self) private var progress

    init(lesson: Lesson) {
        self.lesson = lesson
        _model = State(initialValue: LessonModel(lesson: lesson))
    }

    private var unit: CourseUnit? { GoCourseCatalog.unit(containing: lesson.id) }

    private var tint: Color {
        CourseUnitStyle.tint(for: unit?.id ?? "")
    }

    private var nextLesson: Lesson? { GoCourseCatalog.lesson(after: lesson.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LessonHeaderCard(
                    lesson: lesson,
                    unitTitle: unit?.title ?? "Practice",
                    position: GoCourseCatalog.position(of: lesson.id),
                    tint: tint
                )

                LessonSection(title: "What is going on", systemImage: "text.alignleft", tint: tint) {
                    Text(lesson.explanation)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }

                taskSection

                if lesson.requiresCompiler, !model.canCheck, !model.isChecking {
                    Label(model.toolchainDetail, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(GopherForgeTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let result = model.result {
                    LessonVerdictView(result: result, solution: lesson.idiomaticSolution)
                }

                completion

                // Only for what the course teaches. A challenge belongs to a
                // unit but is reached from Practice, and it has no next lesson
                // — offering one would walk somebody out of the drill they
                // chose into the middle of a unit, and saying "that is the last
                // lesson" would be a plain lie.
                if unit != nil, !lesson.isChallenge {
                    LessonNextStep(next: nextLesson, isFinished: model.isCompleted)
                }
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
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
                        check()
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

    // MARK: - Finishing

    /// Whether this is done, and the way to say so.
    ///
    /// Every lesson can be ticked. It used to be that only a lesson with
    /// nothing to run could, which left four of the seven units with no way to
    /// record progress at all — their lessons are all compile lessons, and a
    /// learner who had done the work elsewhere could not say so.
    ///
    /// The two ways are named rather than left to be guessed. "Check" hands the
    /// work to the compiler; the button below is the learner's own word, and
    /// the app records which of the two happened rather than flattening them
    /// into one tick.
    @ViewBuilder
    private var completion: some View {
        if model.isCompleted {
            finishedCard
        } else {
            unfinishedCard
        }
    }

    private var finishedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                model.isCompilerVerified ? "The compiler passed this" : "Marked done by you",
                systemImage: model.isCompilerVerified
                    ? "checkmark.seal.fill"
                    : "checkmark.circle.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(model.isCompilerVerified ? Color.green : GopherForgeTheme.accent)

            if !model.isCompilerVerified, lesson.isJudgedByCompiler {
                Text("The hidden test has not run. Press Check to have it judged, "
                    + "or use the tick in the toolbar to take this back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (model.isCompilerVerified ? Color.green : GopherForgeTheme.accentSolid).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        // One element, so the identifier belongs to the card rather than
        // being inherited by every label inside it — which made a search
        // for it ambiguous, and made the card three things to VoiceOver.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.lessonCompleted)
    }

    @ViewBuilder
    private var unfinishedCard: some View {
        if lesson.isJudgedByCompiler {
            VStack(alignment: .leading, spacing: 10) {
                Text("Two ways to finish this")
                    .font(.callout.weight(.semibold))
                Text("**Check** compiles your code against the lesson's hidden test and "
                    + "records a pass the compiler witnessed. If you have already worked "
                    + "through this — on paper, in another editor, years ago in another "
                    + "language — say so instead. The app keeps the two apart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(action: check) {
                        Label("Check", systemImage: "checkmark.diamond")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canCheck || model.isChecking)

                    Button(action: markDone) {
                        Text("I've done this")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            // Nothing to run, so the learner's word is the only signal there is
            // and the button carries the page.
            Button(action: markDone) {
                Label("Mark this lesson done", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Done or not, in one tap, from anywhere on the page.
    ///
    /// Labelled rather than a bare circle: an unnamed glyph in a toolbar is a
    /// decoration until you press it and find out.
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
                Label("Done", systemImage: "checkmark.circle.fill")
            }
            .accessibilityLabel("Marked done. Tap to undo.")
            .accessibilityIdentifier(AccessibilityID.lessonUncomplete)
        } else {
            Button(action: markDone) {
                Label("Mark done", systemImage: "circle")
            }
            .accessibilityLabel("Mark as completed")
            .accessibilityIdentifier(AccessibilityID.lessonComplete)
        }
    }

    private func markDone() {
        Task {
            await model.markCompleted()
            await progress.refresh()
        }
    }

    private func check() {
        Task {
            await model.check()
            // The course is showing this lesson's state too, and a pass it
            // never hears about is a tick nobody sees.
            await progress.refresh()
        }
    }

    // MARK: - The task

    @ViewBuilder
    private var taskSection: some View {
        switch lesson.task {
        case let .guidedTyping(target):
            LessonSection(title: "Type this until it is automatic", systemImage: "keyboard", tint: tint) {
                CodeBlock(title: "", code: target)
            }
        case let .fillGaps(template, blanks):
            LessonSection(title: "Fill the gaps", systemImage: "square.dashed", tint: tint) {
                VStack(alignment: .leading, spacing: 8) {
                    CodeBlock(title: "", code: template)
                    Text("Missing: \(blanks.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case let .predict(source, question, answer):
            LessonSection(title: "Predict the output", systemImage: "questionmark.circle", tint: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    CodeBlock(title: "", code: source)
                    Text(question).font(.callout.weight(.medium))
                    DisclosureGroup("Show the answer") {
                        Text(answer)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .tint(tint)
                }
            }
        case .compile:
            LessonSection(title: "Edit until the hidden test passes", systemImage: "hammer", tint: tint) {
                SyntaxCodeEditor(
                    text: $model.editorText,
                    fileKind: .go,
                    fontSize: 13
                )
                .frame(height: 320)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                Text(result.detail).font(.callout.weight(.medium))
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GopherForgeTheme.statusColor(succeeded: result.succeeded).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
