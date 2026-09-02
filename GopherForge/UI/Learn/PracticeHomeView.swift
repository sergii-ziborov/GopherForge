import SwiftUI

/// Practice, gathered in one place and filling up as the course is worked
/// through.
///
/// A locked item is shown rather than hidden, with what opens it. Hiding it
/// would make the screen look finished when it is not, and "two more lessons in
/// Errors" is a reason to go back to the unit.
struct PracticeHomeView: View {
    let completed: Set<String>
    let onQuizFinished: (QuizResult) -> Void
    let onDrillFinished: (MatchingDrillResult) -> Void

    private var groups: [(unit: CourseUnit, items: [PracticeCatalog.Item])] {
        GoCourseCatalog.units.compactMap { unit in
            let items = PracticeCatalog.items(forUnit: unit.id)
            return items.isEmpty ? nil : (unit, items)
        }
    }

    private var unlockedCount: Int {
        PracticeCatalog.unlockedItems(completed: completed).count
    }

    var body: some View {
        List {
            Section {
                PracticeSummaryRow(unlocked: unlockedCount, total: PracticeCatalog.items.count)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(groups, id: \.unit.id) { group in
                Section(group.unit.title) {
                    ForEach(group.items) { item in
                        row(
                            for: item,
                            done: PracticeCatalog.completedCount(
                                inUnit: group.unit.id,
                                completed: completed
                            )
                        )
                    }
                }
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(for item: PracticeCatalog.Item, done: Int) -> some View {
        if item.isUnlocked(completedInUnit: done) {
            NavigationLink {
                destination(for: item)
            } label: {
                PracticeItemRow(item: item, locked: false, remaining: 0)
            }
            .accessibilityIdentifier("practice.\(item.id)")
        } else {
            // Combined into one element before it is named. An identifier on a
            // container is inherited by every label inside it, so the locked
            // row answered a search for it three times and a test asking where
            // it is on screen got "multiple matching elements" instead of a
            // frame. The unlocked branch is a link, which is already one.
            PracticeItemRow(item: item, locked: true, remaining: item.unlocksAfter - done)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("practice.\(item.id)")
        }
    }

    @ViewBuilder
    private func destination(for item: PracticeCatalog.Item) -> some View {
        switch item.kind {
        case let .challenge(lesson): LessonDetailView(lesson: lesson)
        case let .drill(drill): MatchingDrillView(drill: drill, onFinish: onDrillFinished)
        case let .quiz(quiz): QuizView(quiz: quiz, onFinish: onQuizFinished)
        case let .spotTheBug(rounds): SpotTheBugView(rounds: rounds, onFinish: onDrillFinished)
        case let .interview(questions): InterviewQuestionView(questions: questions)
        }
    }
}

/// How much of the practice is open, as a bar rather than a fraction alone.
private struct PracticeSummaryRow: View {
    let unlocked: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(unlocked) of \(total) open")
                .font(.headline)
            ProgressView(value: total == 0 ? 0 : Double(unlocked) / Double(total))
            Text("Challenges, drills and quizzes open as you finish the lessons "
                + "they belong to.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}

private struct PracticeItemRow: View {
    let item: PracticeCatalog.Item
    let locked: Bool
    let remaining: Int

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: locked ? "lock.fill" : item.symbol)
                .font(.body)
                .foregroundStyle(locked ? Color.secondary : CourseUnitStyle.tint(for: item.unitID))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.callout.weight(.medium))
                Text(locked
                    ? "Finish \(remaining) more lesson\(remaining == 1 ? "" : "s") in this unit"
                    : item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .opacity(locked ? 0.55 : 1)
    }
}
