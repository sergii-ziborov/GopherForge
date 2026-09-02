import SwiftUI

/// What the goroutines did, drawn as lanes rather than listed as lines.
///
/// A list of events is the wrong shape for concurrency: the question is always
/// "what was this one doing while that one did that", and a list answers it
/// only by making the reader hold two positions in their head at once. A lane
/// per goroutine puts the answer in the same column.
///
/// Time here is the order events were reported, not a clock. Wall-clock inside
/// a WebAssembly interpreter would say more about the interpreter than about
/// the program, and the lab has never claimed otherwise.
struct ConcurrencyTimelineView: View {
    let trace: ConcurrencyTrace

    private let laneHeight: CGFloat = 46
    private let stepWidth: CGFloat = 58
    private let labelWidth: CGFloat = 96

    /// Events in reported order, which is the x axis.
    private var ordered: [ConcurrencyEvent] { trace.events }

    private var actors: [String] { trace.actors }

    private var stuck: Set<String> { Set(trace.stuckActors) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What each goroutine did", systemImage: "chart.bar.doc.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GopherForgeTheme.accent)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    names
                    lanes
                }
            }

            legend
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier(AccessibilityID.labTimeline)
    }

    // MARK: - Pieces

    private var names: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(actors, id: \.self) { actor in
                HStack(spacing: 4) {
                    Text(actor)
                        .font(.caption.monospaced().weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if stuck.contains(actor) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(GopherForgeTheme.berry)
                    }
                }
                .frame(width: labelWidth, height: laneHeight, alignment: .leading)
            }
        }
    }

    private var lanes: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(actors.enumerated()), id: \.element) { row, actor in
                lane(for: actor)
                    .offset(y: CGFloat(row) * laneHeight)
            }
        }
        .frame(width: CGFloat(max(ordered.count, 1)) * stepWidth, alignment: .topLeading)
    }

    private func lane(for actor: String) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 4)

            // A blocked goroutine is a span, not a moment: it starts where it
            // blocked and ends where it did the next thing — or runs off the
            // end, which is what "never came back" looks like.
            ForEach(blockedSpans(for: actor), id: \.start) { span in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        (span.resumed ? GopherForgeTheme.warning : GopherForgeTheme.berry)
                            .opacity(0.22)
                    )
                    .frame(width: span.width(stepWidth: stepWidth), height: 22)
                    .offset(x: CGFloat(span.start) * stepWidth + stepWidth / 2)
            }

            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, event in
                if event.actor == actor {
                    marker(for: event)
                        .offset(x: CGFloat(index) * stepWidth + stepWidth / 2 - 9)
                }
            }
        }
        .frame(height: laneHeight, alignment: .center)
    }

    private func marker(for event: ConcurrencyEvent) -> some View {
        Image(systemName: symbol(for: event.kind))
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(colour(for: event.kind), in: Circle())
            .accessibilityLabel(event.summary)
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                legendItem(.goroutineStarted, "started")
                legendItem(.send, "sent")
                legendItem(.receive, "received")
                legendItem(.channelClosed, "closed")
                legendItem(.blocked, "blocked")
                legendItem(.goroutineFinished, "finished")
            }
        }
    }

    private func legendItem(_ kind: ConcurrencyEvent.Kind, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol(for: kind))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 15, height: 15)
                .background(colour(for: kind), in: Circle())
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func blockedSpans(for actor: String) -> [ConcurrencyTimelineLayout.BlockedSpan] {
        ConcurrencyTimelineLayout.blockedSpans(for: actor, in: ordered)
    }

    // MARK: - Vocabulary

    private func symbol(for kind: ConcurrencyEvent.Kind) -> String {
        switch kind {
        case .goroutineStarted: "play.fill"
        case .goroutineFinished: "checkmark"
        case .send: "arrow.up.right"
        case .receive: "arrow.down.left"
        case .channelClosed: "xmark"
        case .selectChosen: "arrow.triangle.branch"
        case .contextCancelled: "nosign"
        case .waitGroupAdd: "plus"
        case .waitGroupDone: "minus"
        case .waitGroupWaitReturned: "flag.checkered"
        case .blocked: "pause.fill"
        }
    }

    private func colour(for kind: ConcurrencyEvent.Kind) -> Color {
        switch kind {
        case .goroutineStarted, .goroutineFinished: GopherForgeTheme.aqua
        case .send: GopherForgeTheme.gopherBlue
        case .receive: GopherForgeTheme.deepBlue
        case .channelClosed: GopherForgeTheme.slate
        case .selectChosen: Color(hex: 0x375EAB)
        case .contextCancelled: GopherForgeTheme.berry
        case .waitGroupAdd, .waitGroupDone, .waitGroupWaitReturned: Color(hex: 0x4E8F3E)
        case .blocked: GopherForgeTheme.warning
        }
    }
}
