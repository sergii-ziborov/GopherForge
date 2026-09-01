import SwiftUI

/// What a node on the path has to say for itself.
///
/// Four states rather than three, because "done" is two different claims here
/// and the app should never draw the stronger one for the weaker. A seal is a
/// pass the bundled compiler witnessed; a tick is the learner's own word.
///
/// There is deliberately no locked state. A course written for people who
/// already program is one they will enter sideways — at goroutines, because
/// that is the thing they came for — and a path that refuses them is a path
/// they close. The trail says where the author would start; it does not stand
/// in the doorway.
enum CoursePathState {
    case upcoming
    case next
    case done
    case verified

    var isFinished: Bool {
        self == .done || self == .verified
    }

    /// Said in words, because two similar glyphs are one glyph to VoiceOver.
    var spoken: String {
        switch self {
        case .upcoming: "Not done"
        case .next: "Up next"
        case .done: "Marked done"
        case .verified: "Passed the compiler"
        }
    }
}

/// One stop on the path: a circle you tap and a label beside it.
struct CoursePathNodeView: View {
    let index: Int
    let title: String
    let subtitle: String
    let badge: String
    let symbol: String
    let state: CoursePathState
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let nodeX = CoursePathLayout.nodeCenterX(width: width, index: index)
            let toRight = CoursePathLayout.labelToRight(at: index)
            let labelWidth = CoursePathLayout.labelWidth(for: width)
            let labelX = CoursePathLayout.labelCenterX(
                width: width,
                nodeX: nodeX,
                labelWidth: labelWidth,
                labelToRight: toRight
            )

            ZStack {
                label(toRight: toRight)
                    .frame(width: labelWidth)
                    .position(x: labelX, y: geometry.size.height / 2)

                circle
                    .position(x: nodeX, y: geometry.size.height / 2)
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
        }
    }

    // MARK: - The circle

    private var circle: some View {
        ZStack {
            // The ring is the "you are here", and only the next node has it.
            // A glow on every node is a glow on none.
            if state == .next {
                Circle()
                    .stroke(tint.opacity(0.32), lineWidth: 3)
                    .frame(width: CoursePathLayout.nodeDiameter + 14)
                Circle()
                    .stroke(tint.opacity(0.14), lineWidth: 2)
                    .frame(width: CoursePathLayout.nodeDiameter + 26)
            }

            Circle()
                .fill(fill)
                .frame(width: CoursePathLayout.nodeDiameter, height: CoursePathLayout.nodeDiameter)
                .overlay {
                    Circle().stroke(border, lineWidth: state == .upcoming ? 2 : 1)
                }
                .shadow(color: shadow, radius: state == .next ? 14 : 4, y: 5)

            Image(systemName: glyph)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(glyphColor)
        }
        .frame(width: CoursePathLayout.nodeBox, height: CoursePathLayout.nodeBox)
        .accessibilityHidden(true)
    }

    private var glyph: String {
        switch state {
        case .verified: "checkmark.seal.fill"
        case .done: "checkmark"
        case .next, .upcoming: symbol
        }
    }

    private var fill: LinearGradient {
        switch state {
        case .verified:
            LinearGradient(
                colors: [.green, Color(hex: 0x2E8B57)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .done:
            LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .top, endPoint: .bottom)
        case .next:
            LinearGradient(
                colors: [tint, tint.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .upcoming:
            LinearGradient(
                colors: [tint.opacity(0.10), tint.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Each state picks a colour that contrasts with its own fill. An upcoming
    /// node is nearly the page in the light theme, so a white glyph on it would
    /// be a white glyph on white.
    private var glyphColor: Color {
        state == .upcoming ? tint.opacity(0.85) : .white
    }

    private var border: Color {
        state == .upcoming ? tint.opacity(0.30) : .white.opacity(0.28)
    }

    private var shadow: Color {
        switch state {
        case .next: tint.opacity(0.40)
        case .verified: .green.opacity(0.24)
        case .done: tint.opacity(0.22)
        case .upcoming: .black.opacity(0.06)
        }
    }

    // MARK: - The label

    private func label(toRight: Bool) -> some View {
        VStack(alignment: toRight ? .leading : .trailing, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state == .upcoming ? Color.primary.opacity(0.75) : .primary)
                .lineLimit(2)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(badge)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(badgeTint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(badgeTint.opacity(0.13), in: Capsule())
        }
        .multilineTextAlignment(toRight ? .leading : .trailing)
        .frame(maxWidth: .infinity, alignment: toRight ? .leading : .trailing)
        .accessibilityHidden(true)
    }

    private var badgeTint: Color {
        state == .verified ? .green : tint
    }
}

/// A press that answers, without the blue wash a plain button would put over
/// the whole row.
struct CoursePathButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
