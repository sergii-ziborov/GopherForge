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
                markedLines: workspace.markedLines,
                searchQuery: workspace.highlightQuery,
                revealLine: workspace.revealLine,
                onReveal: workspace.clearReveal
            )
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
/// A scrolling row of chips rather than a segmented control. Six segments on a
/// phone are unreadable — each one gets forty points and the words are cut —
/// and a segmented control does not scroll, so the last two are simply
/// unreachable. Chips size to their own text, carry the pane's colour and its
/// count, and the row scrolls.
struct WorkspacePanePicker: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Binding var selection: WorkspacePane
    let panes: [WorkspacePane]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(panes) { pane in
                        PaneChip(
                            pane: pane,
                            count: count(for: pane),
                            isSelected: pane == selection
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) { selection = pane }
                        }
                        .id(pane)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .accessibilityIdentifier(AccessibilityID.dockPicker)
            .onChange(of: selection) { _, pane in
                // Selecting a pane from elsewhere — a diagnostic tapped in the
                // editor, say — should bring its chip into view rather than
                // leaving the row looking unchanged.
                withAnimation { proxy.scrollTo(pane, anchor: .center) }
            }
        }
    }

    private func count(for pane: WorkspacePane) -> Int {
        switch pane {
        case .problems: workspace.lastResult?.diagnostics.count ?? 0
        case .tests: workspace.lastResult?.tests.count ?? 0
        case .idioms: workspace.idiomFindings.count
        case .code, .output, .terminal: 0
        }
    }
}

/// One tab.
private struct PaneChip: View {
    let pane: WorkspacePane
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: pane.systemImage)
                    .font(.caption2)
                Text(pane.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .fixedSize()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(pane.tint.opacity(isSelected ? 0.3 : 0.2), in: Capsule())
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? pane.tint : Color.secondary)
            .background(
                pane.tint.opacity(isSelected ? 0.18 : 0.07),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    pane.tint.opacity(isSelected ? 0.85 : 0),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pane.\(pane.rawValue)")
        .accessibilityLabel(count > 0 ? "\(pane.title), \(count)" : pane.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
