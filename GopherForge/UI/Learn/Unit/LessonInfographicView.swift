import SwiftUI

/// A scalable, selectable diagram, rather than text baked into a bitmap.
/// The branches and arrows reflect each lesson's authored relationship.
struct LessonInfographicView: View {
    let guide: LessonGuide
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                Text("THE IDEA, VISUALLY").font(.caption2.weight(.bold)).tracking(1.2)
            }
            .foregroundStyle(tint)
            Text(guide.title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if guide.mode == .shared || guide.mode == .fanout {
                branchingDiagram
            } else if guide.mode == .stack {
                verticalDiagram
            } else {
                ViewThatFits(in: .horizontal) {
                    horizontalDiagram
                    verticalDiagram
                }
            }

            Text(guide.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.2)))
        .accessibilityIdentifier("lesson.diagram.\(guide.id)")
    }

    private var horizontalDiagram: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(Array(guide.nodes.enumerated()), id: \.offset) { index, node in
                if index > 0 { connector(horizontal: true) }
                nodeCard(node, index: index).frame(minWidth: 160)
            }
        }
    }

    private var verticalDiagram: some View {
        VStack(spacing: 8) {
            ForEach(Array(guide.nodes.enumerated()), id: \.offset) { index, node in
                if index > 0 { connector(horizontal: false) }
                nodeCard(node, index: index)
            }
        }
    }

    private var branchingDiagram: some View {
        VStack(spacing: 0) {
            if let first = guide.nodes.first { nodeCard(first, index: 0) }
            BranchConnector(pointsTowardParent: guide.mode == .shared)
                .stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(height: 30)
                .padding(.horizontal, 35)
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(guide.nodes.dropFirst().enumerated()), id: \.offset) { index, node in
                    nodeCard(node, index: index + 1)
                }
            }
        }
    }

    @ViewBuilder
    private func connector(horizontal: Bool) -> some View {
        if guide.mode == .comparison {
            Text("VS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(5)
                .background(tint.opacity(0.1), in: Capsule())
                .accessibilityHidden(true)
        } else {
            Image(systemName: horizontal ? "arrow.right" : "arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
    }

    private func nodeCard(_ node: LessonGuide.Node, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 6) {
                Text(String(index + 1))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(width: 19, height: 19)
                    .background(tint.opacity(0.12), in: Circle())
                Text(node.label)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            GoCodeText(code: node.code, fontSize: 12)
            Text(node.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.15)))
    }
}

private struct BranchConnector: Shape {
    var pointsTowardParent: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: CGPoint(x: rect.midX, y: 0))
        p.addLine(to: mid)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        let tips = pointsTowardParent ? [CGPoint(x: rect.midX, y: 0)]
            : [CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        for tip in tips {
            let direction: CGFloat = pointsTowardParent ? 1 : -1
            p.move(to: CGPoint(x: tip.x - 4, y: tip.y + direction * 5))
            p.addLine(to: tip)
            p.addLine(to: CGPoint(x: tip.x + 4, y: tip.y + direction * 5))
        }
        return p
    }
}
