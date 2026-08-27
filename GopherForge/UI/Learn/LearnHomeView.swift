import SwiftUI

/// The course hub: units, review and the Concurrency Lab.
struct LearnHomeView: View {
    @State private var mastery: [ConceptMastery] = []
    @State private var completed: Set<String> = []
    @State private var stats: LearnerStats = .empty
    @State private var openedScreen: LaunchOptions.Screen?
    private let store = LearningProgressStore()

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
                    MatchingDrillListView(onFinish: record)
                } label: {
                    Label("Drills", systemImage: "link")
                }
                .accessibilityIdentifier(AccessibilityID.drillsEntry)
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
                        Text("\(AchievementCatalog.unlocked(by: stats).count)"
                            + " / \(AchievementCatalog.all.count)")
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
                        UnitDetailView(unit: unit, completed: completed)
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
            case .drills: MatchingDrillListView(onFinish: record)
            case .achievements: AchievementsView(stats: stats)
            case .examples: ExampleLibraryView()
            // Packages live on the Projects side; opening Learn at one would
            // put a screen under a tab it does not belong to.
            case .packages: EmptyView()
            }
        }
        .task {
            await reload()
            openedScreen = LaunchOptions.initialScreen
        }
    }

    /// A finished drill is evidence like any other: it feeds the badges, and
    /// its wrong connections feed the same review queue a failed compile does.
    private func record(_ result: MatchingDrillResult) {
        Task {
            try? await store.record(result)
            await reload()
        }
    }

    private var weakest: [ConceptMastery] {
        mastery.sorted { $0.strength < $1.strength }.prefix(5).map { $0 }
    }

    private func reload() async {
        mastery = (try? await store.mastery()) ?? []
        completed = (try? await store.completedLessonIDs()) ?? []
        stats = (try? await store.learnerStats()) ?? .empty
    }
}

private struct UnitRow: View {
    let unit: CourseUnit
    let completed: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(unit.title).font(.callout.weight(.medium))
            Text(unit.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(doneCount) of \(unit.lessons.count) lessons")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var doneCount: Int {
        unit.lessons.count { completed.contains($0.id) }
    }
}
