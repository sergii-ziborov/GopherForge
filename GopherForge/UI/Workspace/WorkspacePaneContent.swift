import SwiftUI

/// Renders whichever pane is selected.
///
/// Both layouts route through this, so a pane cannot look different depending
/// on which device is showing it.
struct WorkspacePaneContent: View {
    @Environment(WorkspaceModel.self) private var workspace
    let pane: WorkspacePane
    let terminal: ProjectTerminalSession
    let fontSize: Double

    var body: some View {
        @Bindable var workspace = workspace

        switch pane {
        case .code:
            SyntaxCodeEditor(
                text: $workspace.editorText,
                fileKind: workspace.fileKind,
                fontSize: fontSize,
                markedLines: workspace.markedLines
            )
            .accessibilityIdentifier(AccessibilityID.editor)
        case .problems:
            DiagnosticListView(diagnostics: workspace.lastResult?.diagnostics ?? [])
        case .output:
            OutputStreamView(result: workspace.lastResult)
        case .tests:
            TestResultListView(tests: workspace.lastResult?.tests ?? [])
        case .idioms:
            IdiomFindingListView(findings: workspace.idiomFindings)
        case .terminal:
            TerminalPaneView(session: terminal)
        }
    }
}

/// The pane switcher.
///
/// It carries a count badge so a tab worth opening says so, which matters most
/// on iPhone where only one pane is visible at a time.
struct WorkspacePanePicker: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Binding var selection: WorkspacePane
    let panes: [WorkspacePane]

    var body: some View {
        Picker("Pane", selection: $selection) {
            ForEach(panes) { pane in
                Text(title(for: pane)).tag(pane)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityID.dockPicker)
    }

    private func title(for pane: WorkspacePane) -> String {
        let count = switch pane {
        case .problems: workspace.lastResult?.diagnostics.count ?? 0
        case .tests: workspace.lastResult?.tests.count ?? 0
        case .idioms: workspace.idiomFindings.count
        case .code, .output, .terminal: 0
        }
        return count > 0 ? "\(pane.title) \(count)" : pane.title
    }
}
