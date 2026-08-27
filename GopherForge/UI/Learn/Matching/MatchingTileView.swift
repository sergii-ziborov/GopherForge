import SwiftUI

/// One tile.
///
/// Every tile on a board is exactly `MatchingBoardMetrics.tileHeight` tall,
/// whatever it says. That is the whole reason the board is playable with a
/// thumb: a matched pair does not collapse, a longer answer does not push its
/// neighbours down, and the tile you are reaching for is where it was when you
/// started reaching.
struct MatchingTileView: View {
    let text: String
    let state: MatchingDrillSession.TileState
    /// Set on the button itself. An identifier applied to a wrapper does not
    /// reliably reach the control inside it, and a tile nothing can address is
    /// a tile no test can tap.
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .lineLimit(MatchingBoardMetrics.lineLimit)
                // The budget in MatchingDrill keeps authored text inside three
                // lines; this is the floor under a very large Dynamic Type
                // setting, not a licence to write longer tiles.
                .minimumScaleFactor(0.7)
                .frame(
                    maxWidth: .infinity,
                    minHeight: MatchingBoardMetrics.tileHeight,
                    maxHeight: MatchingBoardMetrics.tileHeight,
                    alignment: .leading
                )
                .padding(.horizontal, 10)
                .background(background)
                .overlay(border)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .disabled(state == .matched)
        .animation(.easeOut(duration: 0.15), value: state)
        .accessibilityLabel(text)
        .accessibilityValue(accessibilityValue)
    }

    private var background: some ShapeStyle {
        switch state {
        case .idle: AnyShapeStyle(Color(.secondarySystemBackground))
        case .selected: AnyShapeStyle(Color.accentColor.opacity(0.18))
        case .matched: AnyShapeStyle(Color.green.opacity(0.16))
        case .rejected: AnyShapeStyle(Color.red.opacity(0.16))
        }
    }

    private var foreground: Color {
        state == .matched ? .secondary : .primary
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(borderColor, lineWidth: state == .idle ? 0.5 : 1.5)
    }

    private var borderColor: Color {
        switch state {
        case .idle: Color(.separator)
        case .selected: .accentColor
        case .matched: .green
        case .rejected: .red
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .idle: "not connected"
        case .selected: "selected"
        case .matched: "connected"
        case .rejected: "wrong pair"
        }
    }
}

/// The fixed geometry of a board.
///
/// Constants rather than measurements, deliberately. Measuring the tallest tile
/// and applying it to the rest works, and it also means the board resizes the
/// first time it lays out — which is exactly the jump this is here to prevent.
enum MatchingBoardMetrics {
    static let tileHeight: CGFloat = 78
    static let lineLimit = 3
    static let columnSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 10
}
