import SwiftUI

/// Public practice routes. Existing exercises remain open, without old
/// lesson-count locks or test-only launch arguments.
struct PracticeLibraryView: View {
    var unitID: String? = nil
    @Environment(LearnProgress.self) private var progress
    private var units: [CourseUnit] { GoCourseCatalog.units.filter { unitID == nil || $0.id == unitID } }

    var body: some View {
        List {
            Section {
                NavigationLink { ConcurrencyLabView() } label: {
                    Label("Concurrency Lab", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .accessibilityIdentifier("practice.library.lab")
                Text("Write code, predict the output, match terms, find a bug or check a concept. These formats are open; finishing a lesson is not a prerequisite.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(units) { unit in
                let items = PracticeCatalog.items(forUnit: unit.id)
                if !items.isEmpty {
                    Section(unit.title) {
                        ForEach(items) { item in
                            NavigationLink { destination(item) } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                        Text(item.detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                } icon: { Image(systemName: item.symbol) }
                            }
                            .accessibilityIdentifier("practice.library.\(item.id)")
                        }
                    }
                }
                let codeLessons = unit.teachingLessons.filter(\.requiresCompiler)
                if !codeLessons.isEmpty {
                    Section("\(unit.title) · write code") {
                        ForEach(codeLessons) { lesson in
                            NavigationLink { LessonDetailView(lesson: lesson) } label: {
                                Label(lesson.title, systemImage: "chevron.left.forwardslash.chevron.right")
                            }
                            .accessibilityIdentifier("practice.library.code.\(lesson.id)")
                        }
                    }
                }
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("practice.library")
    }

    @ViewBuilder private func destination(_ item: PracticeCatalog.Item) -> some View {
        switch item.kind {
        case let .challenge(lesson): LessonDetailView(lesson: lesson)
        case let .drill(drill): MatchingDrillView(drill: drill, onFinish: { result in Task { await progress.record(result) } })
        case let .quiz(quiz): QuizView(quiz: quiz) { result in Task { await progress.record(result) } }
        case let .spotTheBug(rounds): SpotTheBugView(rounds: rounds) { result in Task { await progress.record(result) } }
        case let .interview(questions): InterviewQuestionView(questions: questions)
        }
    }
}
