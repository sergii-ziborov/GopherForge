import SwiftUI

/// The course hub: units, review and the Concurrency Lab.
struct LearnHomeView: View {
    @State private var mastery: [ConceptMastery] = []
    @State private var completed: Set<String> = []
    private let store = LearningProgressStore()

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ReviewView()
                } label: {
                    Label("Review", systemImage: "arrow.trianglehead.counterclockwise")
                }
                NavigationLink {
                    ConcurrencyLabView()
                } label: {
                    Label("Concurrency Lab", systemImage: "arrow.triangle.branch")
                }
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
        .task { await reload() }
    }

    private var weakest: [ConceptMastery] {
        mastery.sorted { $0.strength < $1.strength }.prefix(5).map { $0 }
    }

    private func reload() async {
        mastery = (try? await store.mastery()) ?? []
        completed = (try? await store.completedLessonIDs()) ?? []
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
