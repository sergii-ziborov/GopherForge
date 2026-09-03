import SwiftUI

/// One unit on the course screen: a rail, a node on it, and the unit's card.
///
/// The course screen used the same winding path the lessons inside a unit use,
/// and it could not carry the length. Measured: seven units scrolled and nine
/// pinned the main thread for thirty seconds, with everything else unchanged —
/// the path places every node against the full proposed width, and that is work
/// per node on every frame of a scroll.
///
/// A rail costs nothing to lay out and still reads as a route with a position
/// on it. The winding path stays where its node count is small and it works: in
/// a unit, over its own lessons.
struct UnitJourneyRow: View {
    let item: CoursePathItem
    let isFirst: Bool
    let isLast: Bool

    private let railWidth: CGFloat = 44

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rail
            card
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var rail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : item.tint.opacity(0.25))
                .frame(width: 2, height: 14)
            node
            Rectangle()
                .fill(isLast ? Color.clear : item.tint.opacity(0.25))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: railWidth)
    }

    private var node: some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 38, height: 38)
                .overlay { Circle().stroke(border, lineWidth: item.state == .upcoming ? 2 : 1) }

            Image(systemName: glyph)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(item.state == .upcoming ? item.tint.opacity(0.85) : .white)
        }
        // The ring marks where you are, and only there. A ring on every node is
        // a ring on none.
        .overlay {
            if item.state == .next {
                Circle().stroke(item.tint.opacity(0.30), lineWidth: 3).frame(width: 50, height: 50)
            }
        }
        .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(item.state == .upcoming ? Color.primary.opacity(0.8) : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Text(item.badge)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(badgeTint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(badgeTint.opacity(0.13), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(item.tint.opacity(item.state == .next ? 0.35 : 0.14), lineWidth: 1)
        }
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }

    private var glyph: String {
        switch item.state {
        case .verified: "checkmark.seal.fill"
        case .done: "checkmark"
        case .next, .upcoming: item.symbol
        }
    }

    private var fill: Color {
        switch item.state {
        case .verified: .green
        case .done, .next: item.tint
        case .upcoming: item.tint.opacity(0.10)
        }
    }

    private var border: Color {
        item.state == .upcoming ? item.tint.opacity(0.30) : .white.opacity(0.28)
    }

    private var badgeTint: Color {
        item.state == .verified ? .green : item.tint
    }
}

/// The course as a rail of units.
struct CourseJourneyView<Destination: View>: View {
    let items: [CoursePathItem]
    @ViewBuilder let destination: (CoursePathItem) -> Destination

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    DeferredCourseDestination { destination(item) }
                } label: {
                    UnitJourneyRow(
                        item: item,
                        isFirst: index == 0,
                        isLast: index == items.count - 1
                    )
                }
                .buttonStyle(CoursePathButtonStyle())
                .accessibilityIdentifier(item.accessibilityIdentifier)
                .accessibilityLabel("\(index + 1). \(item.title)")
                .accessibilityValue(item.accessibilityValue)
            }
        }
    }
}

/// Builds a destination when it is followed rather than when the link is drawn.
struct DeferredCourseDestination<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View { content() }
}
