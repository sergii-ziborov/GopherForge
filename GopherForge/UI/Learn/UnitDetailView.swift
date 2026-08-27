import SwiftUI

/// One unit: why it exists, then its lessons.
struct UnitDetailView: View {
    let unit: CourseUnit
    let completed: Set<String>
    var onQuizFinished: (QuizResult) -> Void = { _ in }
    var onDrillFinished: (MatchingDrillResult) -> Void = { _ in }

    private var quiz: Quiz? { QuizCatalog.quiz(forUnit: unit.id) }
    private var drills: [MatchingDrill] { MatchingDrillCatalog.drills(forUnit: unit.id) }
    private var doneCount: Int { unit.lessons.count { completed.contains($0.id) } }

    var body: some View {
        List {
            Section {
                UnitHeaderCard(unit: unit, done: doneCount, total: unit.lessons.count)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                Text(unit.translationNote)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("If you already program")
            }

            Section("Lessons") {
                ForEach(unit.lessons) { lesson in
                    NavigationLink {
                        LessonDetailView(lesson: lesson)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: completed.contains(lesson.id)
                                ? "checkmark.circle.fill"
                                : "circle")
                                .foregroundStyle(completed.contains(lesson.id)
                                    ? Color.green
                                    : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title).font(.callout.weight(.medium))
                                Text(lesson.objective)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.lesson(lesson.id))
                }
            }

            if !drills.isEmpty || quiz != nil {
                Section {
                    ForEach(drills) { drill in
                        NavigationLink {
                            MatchingDrillView(drill: drill, onFinish: onDrillFinished)
                        } label: {
                            PracticeRow(
                                title: drill.title,
                                detail: "\(drill.pairs.count) pairs to connect",
                                symbol: "link",
                                tint: .blue
                            )
                        }
                        .accessibilityIdentifier("drill.\(drill.id)")
                    }

                    if let quiz {
                        NavigationLink {
                            QuizView(quiz: quiz, onFinish: onQuizFinished)
                        } label: {
                            PracticeRow(
                                title: "Quiz",
                                detail: "\(quiz.questions.count) questions · four in five passes",
                                symbol: "checklist",
                                tint: GopherForgeTheme.ember
                            )
                        }
                        .accessibilityIdentifier(AccessibilityID.quizEntry)
                    }
                } header: {
                    Text("Practise")
                } footer: {
                    Text("Anything you get wrong here joins what the compiler saw you get "
                        + "wrong, in the same review queue.")
                }
            }
        }
        .navigationTitle(unit.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
