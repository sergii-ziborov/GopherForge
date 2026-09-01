import SwiftUI

/// Draws the trace: one column per goroutine, one row per event.
///
/// A timeline rather than a graph, because what a learner needs to see is the
/// order things happened and where a column simply stops.
struct ConcurrencyTraceView: View {
    let trace: ConcurrencyTrace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What the program reported")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if !trace.channels.isEmpty {
                Text("channels: \(trace.channels.joined(separator: ", "))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(trace.events) { event in
                    EventRow(event: event, isStuck: trace.stuckActors.contains(event.actor))
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct EventRow: View {
    let event: ConcurrencyEvent
    let isStuck: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(event.sequence)")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .trailing)

            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(event.summary)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if event.isBlocking, isStuck {
                Text("never resumed")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var symbol: String {
        switch event.kind {
        case .goroutineStarted: "play.circle"
        case .goroutineFinished: "stop.circle"
        case .send: "arrow.right.circle"
        case .receive: "arrow.left.circle"
        case .channelClosed: "xmark.circle"
        case .selectChosen: "arrow.triangle.branch"
        case .contextCancelled: "bolt.slash"
        case .waitGroupAdd: "plus.circle"
        case .waitGroupDone: "checkmark.circle"
        case .waitGroupWaitReturned: "flag.checkered"
        case .blocked: "pause.circle"
        }
    }

    private var tint: Color {
        switch event.kind {
        case .blocked: isStuck ? .red : GopherForgeTheme.warning
        case .channelClosed, .contextCancelled: GopherForgeTheme.accent
        case .goroutineFinished, .waitGroupDone, .waitGroupWaitReturned: .green
        default: GopherForgeTheme.slate
        }
    }
}
