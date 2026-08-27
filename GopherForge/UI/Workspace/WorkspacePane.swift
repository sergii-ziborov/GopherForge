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

    /// The colour this pane is recognised by. Problems are orange, tests are
    /// green, and the rest take the app's own tints — so the switcher can be
    /// read by shape at a glance rather than by reading six words.
    var tint: Color {
        switch self {
        case .code: GopherForgeTheme.anvil
        case .problems: .orange
        case .output: .teal
        case .tests: .green
        case .idioms: .yellow
        case .terminal: .purple
        }
    }

    /// On iPad the editor is always on screen, so the dock offers everything
    /// except the code itself.
    static var dockPanes: [WorkspacePane] {
        allCases.filter { $0 != .code }
    }
}
