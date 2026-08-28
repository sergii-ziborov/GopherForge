import SwiftUI

/// The course hub: units, review and the Concurrency Lab.
struct LearnHomeView: View {
    /// Shared with every screen below, so a tick made three screens deep is
    /// visible on the way back out. It used to be a value handed down, which
    /// meant a lesson marked complete changed nothing anybody could see until
    /// the app was relaunched.
    @Environment(LearnProgress.self) private var progress
    @State private var openedScreen: LaunchOptions.Screen?

    private var completed: Set<String> { progress.completed }
    private var stats: LearnerStats { progress.stats }
    private var mastery: [ConceptMastery] { progress.mastery }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ReviewView()
                } label: {
                    Label("Review", systemImage: "arrow.trianglehead.counterclockwise")
                }
                .accessibilityIdentifier(AccessibilityID.reviewEntry)
                NavigationLink {
                    ConcurrencyLabView()
                } label: {
                    Label("Concurrency Lab", systemImage: "arrow.triangle.branch")
                }
                .accessibilityIdentifier(AccessibilityID.labEntry)
                NavigationLink {
                    PracticeHomeView(
                        completed: completed,
                        onQuizFinished: record,
                        onDrillFinished: record
                    )
                } label: {
                    LabeledContent {
                        Text("\(PracticeCatalog.unlockedItems(completed: completed).count)"
                            + " / \(PracticeCatalog.items.count)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Practice", systemImage: "figure.mind.and.body")
                    }
                }
                .accessibilityIdentifier(AccessibilityID.practiceEntry)
                NavigationLink {
                    ExampleLibraryView()
                } label: {
                    Label("Examples", systemImage: "books.vertical")
                }
                .accessibilityIdentifier(AccessibilityID.examplesEntry)
                NavigationLink {
                    AchievementsView(stats: stats)
                } label: {
                    LabeledContent {
                        Text("\(AchievementCatalog.earnedLevelCount(by: stats))"
                            + " / \(AchievementCatalog.totalLevelCount)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Achievements", systemImage: "rosette")
                    }
                }
                .accessibilityIdentifier(AccessibilityID.achievementsEntry)
            } footer: {
                Text("Review is chosen from what the compiler and the idiom coach saw you get wrong.")
            }

            Section("Course") {
                ForEach(GoCourseCatalog.units) { unit in
                    NavigationLink {
                        UnitDetailView(unit: unit)
                    } label: {
                        UnitRow(unit: unit, completed: completed)
                    }
                    .accessibilityIdentifier(AccessibilityID.unit(unit.id))
                }
            }

            if !weakest.isEmpty {
                Section("Weakest concepts") {
                    ForEach(weakest) { concept in
                        HStack {
                            Text(concept.conceptTag).font(.caption.monospaced())
                            Spacer()
                            ProgressView(value: concept.strength)
                                .frame(width: 80)
                        }
                    }
                }
            }
        }
        .navigationTitle("Learn")
        .navigationDestination(item: $openedScreen) { screen in
            switch screen {
            case .lab: ConcurrencyLabView()
            case .review: ReviewView()
            case .drills:
                PracticeHomeView(
                    completed: completed,
                    onQuizFinished: record,
                    onDrillFinished: record
                )
            case .achievements: AchievementsView(stats: stats)
            case .examples: ExampleLibraryView()
            // Packages live on the Projects side; opening Learn at one would
            // put a screen under a tab it does not belong to.
            case .packages: EmptyView()
            }
        }
        .task {
            await progress.refresh()
            openedScreen = LaunchOptions.initialScreen
        }
    }

    /// A finished drill is evidence like any other: it feeds the badges, and
    /// its wrong connections feed the same review queue a failed compile does.
    private func record(_ result: MatchingDrillResult) {
        Task { await progress.record(result) }
    }

    /// A quiz is evidence like any other: it feeds the badges, and its wrong
    /// answers feed the same review queue a failed compile does.
    private func record(_ result: QuizResult) {
        Task { await progress.record(result) }
    }

    private var weakest: [ConceptMastery] {
        mastery.sorted { $0.strength < $1.strength }.prefix(5).map { $0 }
    }

}

/// A unit in the course list.
///
/// Colour and a symbol per unit, because six grey rows of text are hard to tell
/// apart at a glance and this is a list people come back to daily. The ring
/// carries the progress, so how far through it is readable before the words.
private struct UnitRow: View {
    let unit: CourseUnit
    let completed: Set<String>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            UnitProgressRing(
                fraction: unit.teachingLessons.isEmpty ? 0 : Double(doneCount) / Double(unit.teachingLessons.count),
                symbol: CourseUnitStyle.symbol(for: unit.id)
            )
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(unit.title).font(.callout.weight(.medium))
                Text(unit.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text("\(doneCount) of \(unit.teachingLessons.count) lessons")
                    if let quiz = QuizCatalog.quiz(forUnit: unit.id) {
                        Label("\(quiz.questions.count)", systemImage: "checklist")
                    }
                    if !MatchingDrillCatalog.drills(forUnit: unit.id).isEmpty {
                        Image(systemName: "link")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .listRowBackground(
            LinearGradient(
                colors: CourseUnitStyle.gradient(for: unit.id),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var doneCount: Int {
        unit.teachingLessons.count { completed.contains($0.id) }
    }
}
