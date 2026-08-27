import SwiftUI

/// The matching board: terms down the left, meanings down the right, tap one of
/// each to connect them.
///
/// Two fixed columns rather than a flow: the rows line up, every tile is the
/// same height, and nothing is ever removed — so the board you learn the shape
/// of on the first pair is the board you finish on.
struct MatchingDrillView: View {
    @State private var session: MatchingDrillSession
    @State private var didRecord = false
    private let onFinish: (MatchingDrillResult) -> Void

    init(drill: MatchingDrill, onFinish: @escaping (MatchingDrillResult) -> Void = { _ in }) {
        _session = State(initialValue: MatchingDrillSession(drill: drill))
        self.onFinish = onFinish
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                board
                if session.isComplete { completion }
            }
            .padding(16)
        }
        .navigationTitle(session.drill.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Restart", systemImage: "arrow.clockwise", action: restart)
                    .accessibilityIdentifier(AccessibilityID.drillRestart)
            }
        }
        .onChange(of: session.isComplete) { _, complete in
            guard complete, !didRecord else { return }
            didRecord = true
            onFinish(session.result())
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.drill.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: session.progress)
            HStack(spacing: 12) {
                Label(
                    "\(session.matchedPairs.count) of \(session.drill.pairs.count)",
                    systemImage: "link"
                )
                if session.mistakes > 0 {
                    Label("\(session.mistakes)", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier(AccessibilityID.drillProgress)
    }

    private var board: some View {
        // Rows rather than two independent columns: paired rows keep the two
        // sides aligned at every Dynamic Type size, and a row is one tap target
        // tall on both sides.
        VStack(spacing: MatchingBoardMetrics.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: MatchingBoardMetrics.columnSpacing) {
                    tile(row.prompt)
                    tile(row.answer)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.drillBoard)
    }

    @ViewBuilder
    private func tile(_ tile: MatchingDrillSession.Tile?) -> some View {
        if let tile {
            MatchingTileView(text: tile.text, state: session.state(of: tile)) {
                session.select(tile)
            }
            .accessibilityIdentifier("drill.tile.\(tile.id)")
        } else {
            // Only reachable if the two sides ever differ in count, which the
            // model forbids. An empty slot keeps the grid rather than shifting.
            Color.clear.frame(height: MatchingBoardMetrics.tileHeight)
        }
    }

    private var completion: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                session.isPerfect ? "Perfect run" : "Drill complete",
                systemImage: session.isPerfect ? "star.fill" : "checkmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(session.isPerfect ? Color.orange : Color.green)

            Text(
                session.isPerfect
                    ? "Every pair on the first try."
                    : "\(session.mistakes) wrong connection\(session.mistakes == 1 ? "" : "s"). "
                        + "Those concepts will come back in Review."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier(AccessibilityID.drillComplete)
    }

    private struct Row {
        let prompt: MatchingDrillSession.Tile?
        let answer: MatchingDrillSession.Tile?
    }

    private var rows: [Row] {
        let count = max(session.prompts.count, session.answers.count)
        return (0..<count).map { index in
            Row(
                prompt: index < session.prompts.count ? session.prompts[index] : nil,
                answer: index < session.answers.count ? session.answers[index] : nil
            )
        }
    }

    private func restart() {
        session = MatchingDrillSession(drill: session.drill)
        didRecord = false
    }
}
