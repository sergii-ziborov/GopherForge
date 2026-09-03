import SwiftUI

/// The course as a path: where you are, what is next, and the practice that
/// hangs off it.
///
/// It used to be a `List` — a section of links above seven grey rows. A list
/// answers "what is in this course". Someone opening the app on a ninth
/// evening is asking "where was I", and that is a question a shape answers
/// faster than a paragraph.
struct LearnHomeView: View {
    /// Shared with every screen below, so a tick made three screens deep is
    /// visible on the way back out. It used to be a value handed down, which
    /// meant a lesson marked complete changed nothing anybody could see until
    /// the app was relaunched.
    @Environment(LearnProgress.self) private var progress
    @State private var openedScreen: LaunchOptions.Screen?
    /// Held by identifier rather than by value: a `Lesson` carries its starter
    /// source and its hidden test, and a navigation destination wants
    /// something small and hashable to key on.
    @State private var openedLessonID: String?

    private var completed: Set<String> { progress.completed }
    private var stats: LearnerStats { progress.stats }
    private var mastery: [ConceptMastery] { progress.mastery }

    private var units: [CourseUnit] { GoCourseCatalog.units }

    private var teachingLessons: [Lesson] {
        units.flatMap(\.teachingLessons)
    }

    private var doneCount: Int {
        teachingLessons.count { completed.contains($0.id) }
    }

    /// Where "Continue" goes: the first lesson not yet done, or the beginning
    /// again once the course is finished.
    private var nextLesson: Lesson? {
        teachingLessons.first { !completed.contains($0.id) } ?? teachingLessons.first
    }

    /// The unit the path marks as "you are here".
    private var nextUnitID: String? {
        units.first { unit in
            unit.teachingLessons.contains { !completed.contains($0.id) }
        }?.id
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 26) {
                CourseHeroCard(
                    doneCount: doneCount,
                    totalCount: teachingLessons.count,
                    unitCount: units.count,
                    verifiedCount: progress.compilerVerified.count,
                    isFinished: doneCount == teachingLessons.count && !teachingLessons.isEmpty,
                    onContinue: { openedLessonID = nextLesson?.id }
                )

                LearnToolRow(
                    practiceUnlocked: PracticeCatalog.unlockedItems(completed: completed).count,
                    practiceTotal: PracticeCatalog.items.count,
                    badgesEarned: AchievementCatalog.earnedLevelCount(by: stats),
                    badgesTotal: AchievementCatalog.totalLevelCount,
                    onQuizFinished: record,
                    onDrillFinished: record,
                    completed: completed,
                    stats: stats
                )

                unitPath

                if !weakest.isEmpty {
                    WeakestConceptsCard(concepts: weakest)
                }

                CoursePathLegend()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Learn")
        .navigationDestination(item: $openedLessonID) { lessonID in
            if let lesson = GoCourseCatalog.lesson(id: lessonID) {
                LessonDetailView(lesson: lesson)
            }
        }
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

    // MARK: - The path

    private var unitPath: some View {
        // Built here rather than inside the path's `GeometryReader`. A
        // `GeometryReader` evaluates its content during layout, outside the
        // scope SwiftUI wraps around `body` to observe what it read — so
        // progress read in there is read without registering a dependency, and
        // the screen keeps the state it was built with.
        let items = units.enumerated().map { _, unit in
            CoursePathItem(
                id: unit.id,
                title: unit.title,
                subtitle: unit.summary,
                badge: badge(for: unit),
                symbol: CourseUnitStyle.symbol(for: unit.id),
                state: state(for: unit),
                tint: CourseUnitStyle.tint(for: unit.id),
                accessibilityIdentifier: AccessibilityID.unit(unit.id),
                accessibilityValue: state(for: unit).spoken
            )
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("The course")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            CourseJourneyView(items: items) { item in
                if let unit = GoCourseCatalog.unit(id: item.id) {
                    UnitDetailView(unit: unit)
                }
            }
        }
    }

    private func state(for unit: CourseUnit) -> CoursePathState {
        let lessons = unit.teachingLessons
        guard !lessons.isEmpty else { return .upcoming }
        if lessons.allSatisfy({ completed.contains($0.id) }) {
            return lessons.allSatisfy { progress.isCompilerVerified($0.id) } ? .verified : .done
        }
        return unit.id == nextUnitID ? .next : .upcoming
    }

    private func badge(for unit: CourseUnit) -> String {
        let lessons = unit.teachingLessons
        let done = lessons.count { completed.contains($0.id) }
        return "\(done) / \(lessons.count) lessons"
    }

    // MARK: - Recording

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

/// The five concepts the learner is weakest at, kept where the course is
/// rather than behind another tap: it is the reason Review has anything in it.
private struct WeakestConceptsCard: View {
    let concepts: [ConceptMastery]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weakest concepts")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(concepts) { concept in
                HStack(spacing: 12) {
                    Text(concept.conceptTag)
                        .font(.caption.monospaced())
                    Spacer(minLength: 8)
                    ProgressView(value: concept.strength)
                        .tint(GopherForgeTheme.accent)
                        .frame(width: 90)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// What the marks on the path mean, said once rather than guessed at.
private struct CoursePathLegend: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                LegendMark(color: .green, symbol: "checkmark.seal.fill", text: "Compiler passed")
                LegendMark(color: GopherForgeTheme.gopherBlue, symbol: "checkmark", text: "Marked done")
                LegendMark(color: GopherForgeTheme.slate, symbol: "circle", text: "Not yet")
            }
            Text("Nothing is locked. The trail is where the course would start you, not a gate.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LegendMark: View {
    let color: Color
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color, in: Circle())
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
