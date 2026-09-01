import SwiftUI

/// What to practise next, and why.
struct ReviewView: View {
    @State private var items: [ReviewScheduler.Item] = []
    @State private var hasLoaded = false
    private let store = LearningProgressStore.shared
    private let scheduler = ReviewScheduler()

    var body: some View {
        List {
            if items.isEmpty, hasLoaded {
                Section {
                    Text("Nothing is due. Review fills up from the mistakes the compiler and the idiom coach actually see.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(items) { item in
                NavigationLink {
                    LessonDetailView(lesson: item.lesson)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.lesson.title).font(.callout.weight(.medium))
                        Text(item.reason).font(.caption).foregroundStyle(.secondary)
                        Text(item.conceptTag).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func reload() async {
        let mastery = (try? await store.mastery()) ?? []
        items = scheduler.nextItems(mastery: mastery)
        hasLoaded = true
    }
}
