import SwiftUI

/// One stop on a course path, prepared before the path draws it.
///
/// A value type rather than a lesson or a unit on purpose. The path lays itself
/// out inside a `GeometryReader`, and a `GeometryReader` evaluates its content
/// during layout — outside the observation scope SwiftUI wraps around `body`.
/// Anything read from `LearnProgress` in there is read without registering a
/// dependency, so the screen keeps whatever state it was built with and a
/// lesson marked done three screens deep changes nothing on the way back out.
///
/// That is the same defect the unit list had before, in a new place. The rule
/// this type exists to enforce: progress is read in `body`, turned into these,
/// and handed to the path already decided.
struct CoursePathItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let symbol: String
    let state: CoursePathState
    let tint: Color
    /// What a UI test addresses this node by.
    let accessibilityIdentifier: String
    /// What the node says it is, said in words rather than as a glyph.
    let accessibilityValue: String
}

/// A column of nodes on a dashed trail, each one a link to somewhere.
struct CoursePathView<Destination: View>: View {
    let items: [CoursePathItem]
    let trailTint: Color
    @ViewBuilder let destination: (CoursePathItem) -> Destination

    /// Measured once and kept, rather than read from a `GeometryReader` the
    /// path lays itself out inside.
    ///
    /// This was a `GeometryReader` wrapping the whole path, and it froze the
    /// app. A reader inside a lazy stack inside a scroll view reports new
    /// geometry as the scroll moves, its content rebuilds, and the rebuild
    /// feeds the next report — measured on the course screen, a swipe pinned
    /// the main thread for thirty seconds. Idle was fine, which is what made it
    /// look like a test problem rather than a frozen screen.
    ///
    /// Reading it in a background that does not depend on the value breaks the
    /// loop: the width changes on rotation and on nothing else.
    @State private var width: CGFloat = 0

    var body: some View {
        // Lazy on purpose. The list this replaced built only the rows on
        // screen; a plain stack builds every one, and the course screen's cost
        // then grows with the length of the course rather than with what is
        // visible — measured, seven units scrolled and nine did not.
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    DeferredDestination { destination(item) }
                } label: {
                    CoursePathNodeView(
                        index: index,
                        width: width,
                        title: item.title,
                        subtitle: item.subtitle,
                        badge: item.badge,
                        symbol: item.symbol,
                        state: item.state,
                        tint: item.tint
                    )
                }
                .buttonStyle(CoursePathButtonStyle())
                .accessibilityIdentifier(item.accessibilityIdentifier)
                .accessibilityLabel("\(index + 1). \(item.title)")
                .accessibilityValue(item.accessibilityValue)
            }
        }
        .frame(maxWidth: .infinity)
        .background { CoursePathTrail(nodeCount: items.count, width: width, tint: trailTint) }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            }
        }
    }
}

/// Builds a navigation destination when it is followed, not when the link is
/// drawn.
///
/// `NavigationLink` takes the destination as a value, so writing it inline
/// constructs every one of them up front. That is affordable for a cheap view
/// and it was not here: a lesson's model probes the bundled toolchain in its
/// initialiser, so drawing a unit of six lessons ran six probes on the main
/// thread before anything appeared. The list this path replaced was lazy and
/// hid the cost; the path is not, and made it thirty seconds of a frozen main
/// thread.
private struct DeferredDestination<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View { content() }
}
