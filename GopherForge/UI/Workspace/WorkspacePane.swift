import SwiftUI

/// The panes a workspace can show.
///
/// One list for both layouts, because iPhone shows them as full-height tabs
/// and iPad shows the editor beside a dock — and the two must never drift into
/// offering different things.
enum WorkspacePane: String, CaseIterable, Identifiable {
    case code
    case problems
    case output
    case tests
    case idioms
    case terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .code: "Code"
        case .problems: "Problems"
        case .output: "Output"
        case .tests: "Tests"
        case .idioms: "Idioms"
        case .terminal: "Terminal"
        }
    }

    var systemImage: String {
        switch self {
        case .code: "chevron.left.forwardslash.chevron.right"
        case .problems: "exclamationmark.triangle"
        case .output: "text.alignleft"
        case .tests: "checkmark.diamond"
        case .idioms: "lightbulb"
        case .terminal: "terminal"
        }
    }

    /// The colour this pane is recognised by. Tests are green and problems are
    /// amber, which is what those two mean everywhere; the rest take the app's
    /// own tints — so the switcher can be read by shape at a glance rather than
    /// by reading six words.
    ///
    /// Idioms used to be plain yellow, which on a white dock is a chip nobody
    /// with ordinary eyesight can read. Go's pink carries at the same size.
    var tint: Color {
        switch self {
        case .code: GopherForgeTheme.slate
        case .problems: GopherForgeTheme.warning
        case .output: GopherForgeTheme.aqua
        case .tests: .green
        case .idioms: GopherForgeTheme.berry
        case .terminal: .purple
        }
    }

    /// On iPad the editor is always on screen, so the dock offers everything
    /// except the code itself.
    static var dockPanes: [WorkspacePane] {
        allCases.filter { $0 != .code }
    }
}
