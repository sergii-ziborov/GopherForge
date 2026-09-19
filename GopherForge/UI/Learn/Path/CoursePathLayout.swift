import SwiftUI

/// Where the nodes of a course path sit, and how the trail joins them.
///
/// The course is a path rather than a list because a list answers "what is
/// there" and a path answers "where am I" — which is the question someone
/// opening a course for the ninth evening actually has.
///
/// The switchback is four steps rather than two. Strict alternation reads as a
/// zigzag and makes every row feel identical; holding each side for two rows
/// gives the eye a direction to follow and leaves room for the label beside the
/// node instead of under it.
enum CoursePathLayout {
    static let edgeInset: CGFloat = 10
    static let nodeDiameter: CGFloat = 74
    /// The tappable square around a node, larger than the drawn circle so the
    /// glow and the ready ring are inside the button rather than clipped by it.
    static let nodeBox: CGFloat = 96
    static let labelGap: CGFloat = 8
    static let rowHeight: CGFloat = 130

    static func trailFraction(at index: Int) -> CGFloat {
        switch index % 4 {
        case 0, 3: 0.26
        default: 0.74
        }
    }

    /// The label goes on whichever side has the room.
    static func labelToRight(at index: Int) -> Bool {
        trailFraction(at: index) < 0.5
    }

    static func nodeCenterX(width: CGFloat, index: Int) -> CGFloat {
        let radius = nodeBox / 2
        let minimum = edgeInset + radius
        let maximum = max(minimum, width - edgeInset - radius)
        return min(max(width * trailFraction(at: index), minimum), maximum)
    }

    static func labelWidth(for width: CGFloat) -> CGFloat {
        let available = max(0, width - edgeInset * 2)
        return min(230, available, max(120, width * 0.46))
    }

    static func labelCenterX(
        width: CGFloat,
        nodeX: CGFloat,
        labelWidth: CGFloat,
        labelToRight: Bool
    ) -> CGFloat {
        let halfLabel = labelWidth / 2
        let direction: CGFloat = labelToRight ? 1 : -1
        let ideal = nodeX + direction * (nodeBox / 2 + labelGap + halfLabel)
        let minimum = edgeInset + halfLabel
        let maximum = max(minimum, width - edgeInset - halfLabel)
        return min(max(ideal, minimum), maximum)
    }

    static func centerY(at index: Int) -> CGFloat {
        CGFloat(index) * rowHeight + rowHeight / 2
    }

    static func height(forNodes count: Int) -> CGFloat {
        CGFloat(max(count, 1)) * rowHeight + 8
    }
}

/// The dashed trail the nodes sit on, drawn in one pass.
///
/// A `Canvas` rather than stroked `Path` views. The path is one drawing whose
/// shape only depends on how many nodes there are, and as a pair of Shape views
/// inside a scrolling stack it was re-proposed and re-stroked on every frame.
struct CoursePathTrail: View {
    let nodeCount: Int
    let width: CGFloat
    let tint: Color

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
            let path = trail
            context.stroke(
                path,
                with: .color(tint.opacity(0.10)),
                style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(tint.opacity(0.45)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [3, 9])
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var trail: Path {
        Path { path in
            guard nodeCount > 0, width > 0 else { return }
            var current = point(at: 0)
            path.move(to: current)

            for index in 1..<nodeCount {
                let next = point(at: index)
                // Control points pulled most of the way towards each other
                // rather than to the midpoint. The curve then leaves each node
                // vertically and does its sideways travel in a short band in
                // the middle — which is the gap between two labels, rather
                // than across the words in them.
                let reach = (next.y - current.y) * 0.85
                path.addCurve(
                    to: next,
                    control1: CGPoint(x: current.x, y: current.y + reach),
                    control2: CGPoint(x: next.x, y: next.y - reach)
                )
                current = next
            }
        }
    }

    private func point(at index: Int) -> CGPoint {
        CGPoint(
            x: CoursePathLayout.nodeCenterX(width: width, index: index),
            y: CoursePathLayout.centerY(at: index)
        )
    }
}
