import SwiftUI

/// Every drill, with what each one is for.
struct MatchingDrillListView: View {
    let drills: [MatchingDrill]
    let onFinish: (MatchingDrillResult) -> Void

    init(
        drills: [MatchingDrill] = MatchingDrillCatalog.drills,
        onFinish: @escaping (MatchingDrillResult) -> Void = { _ in }
    ) {
        self.drills = drills
        self.onFinish = onFinish
    }

    var body: some View {
        List {
            Section {
                ForEach(drills) { drill in
                    NavigationLink {
                        MatchingDrillView(drill: drill, onFinish: onFinish)
                    } label: {
                        DrillRow(drill: drill)
                    }
                    .accessibilityIdentifier("drill.\(drill.id)")
                }
            } footer: {
                Text("Connect a term on the left with what it means on the right. "
                    + "A wrong connection is recorded against the same concept the "
                    + "compiler would have flagged, so it comes back in Review.")
            }
        }
        .navigationTitle("Drills")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DrillRow: View {
    let drill: MatchingDrill

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(drill.title).font(.body)
            Text(drill.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(drill.pairs.count) pairs")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
    }
}
