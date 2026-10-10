import SwiftUI

/// Renders whichever pane is selected.
///
/// Every layout routes through this, so a pane cannot look different depending
/// on which device is showing it.
struct WorkspacePaneContent: View {
    @Environment(WorkspaceModel.self) private var workspace
    let pane: WorkspacePane
    let terminal: ProjectTerminalSession
    let fontSize: Double
    var focusRequest = 0
    var keyboardCommandsOnly = false
    var onEditorReady: ((UITextView) -> Void)?

    /// What a tap on a diagnostic does after moving the editor; a single work
    /// pane switches to Code, while a layout with a visible editor need not.
    var onRevealCode: () -> Void = {}

    var body: some View {
        @Bindable var workspace = workspace

        switch pane {
        case .code:
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(GopherForgeTheme.accent)
                    Text(workspace.selectedFile)
                        .font(.caption.monospaced().weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    if workspace.hasUnsavedChanges {
                        Circle()
                            .fill(GopherForgeTheme.accent)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("Unsaved changes")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(.secondarySystemBackground))
                Divider()
                SyntaxCodeEditor(
                    // Through the model's setter rather than straight at the
                    // property: every keystroke has to reach the project and
                    // autosave, and a plain binding reaches neither.
                    text: Binding(
                        get: { workspace.editorText },
                        set: { workspace.updateEditorText($0) }
                    ),
                    fileKind: workspace.fileKind,
                    fontSize: fontSize,
                    markedLines: workspace.markedLines,
                    searchQuery: workspace.highlightQuery,
                    revealLine: workspace.revealLine,
                    onReveal: workspace.clearReveal,
                    focusRequest: focusRequest,
                    externalKeyboardAccessory: keyboardCommandsOnly,
                    onTextViewReady: onEditorReady
                )
            }
        case .problems:
            DiagnosticListView(diagnostics: workspace.lastResult?.diagnostics ?? [], onReveal: onRevealCode)
        case .output:
            OutputStreamView(
                result: workspace.lastResult,
                progress: workspace.runningStep,
                siteURL: workspace.lastResult?.phase == .run && workspace.lastResult?.succeeded == true
                    ? workspace.sitePreviewURL : nil,
                siteGeneration: workspace.siteGeneration
            )
        case .tests:
            TestResultListView(tests: workspace.lastResult?.tests ?? [])
        case .idioms:
            IdiomFindingListView(findings: workspace.idiomFindings)
        case .terminal:
            TerminalPaneView(
                session: terminal,
                focusRequest: focusRequest,
                keyboardCommandsOnly: keyboardCommandsOnly
            )
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
        HStack(spacing: 0) {
            Menu {
                ForEach(panes) { pane in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selection = pane }
                    } label: {
                        Label(pane.title, systemImage: pane.systemImage)
                    }
                    .accessibilityIdentifier("pane.menu.\(pane.rawValue)")
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("pane.more")
            .accessibilityLabel("Choose panel")
            Divider().frame(height: 24)

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
                    withAnimation { proxy.scrollTo(pane, anchor: .center) }
                }
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
