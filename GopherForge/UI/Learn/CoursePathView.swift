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

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                CoursePathTrail(
                    nodeCount: items.count,
                    width: geometry.size.width,
                    tint: trailTint
                )

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        destination(item)
                    } label: {
                        CoursePathNodeView(
                            index: index,
                            title: item.title,
                            subtitle: item.subtitle,
                            badge: item.badge,
                            symbol: item.symbol,
                            state: item.state,
                            tint: item.tint
                        )
                    }
                    .buttonStyle(CoursePathButtonStyle())
                    .frame(width: geometry.size.width, height: CoursePathLayout.rowHeight)
                    .offset(y: CGFloat(index) * CoursePathLayout.rowHeight)
                    .accessibilityIdentifier(item.accessibilityIdentifier)
                    .accessibilityLabel("\(index + 1). \(item.title)")
                    .accessibilityValue(item.accessibilityValue)
                }
            }
        }
        .frame(height: CoursePathLayout.height(forNodes: items.count))
    }
}
