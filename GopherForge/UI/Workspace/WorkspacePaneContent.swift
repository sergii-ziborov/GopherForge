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
    var compactChrome = false
    var focusRequest = 0
    var keyboardCommandsOnly = false
    var onEditorReady: ((UITextView) -> Void)?

    /// What a tap on a diagnostic does after moving the editor; a single work
    /// pane switches to Code, while a layout with a visible editor need not.
    var onRevealCode: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            if workspace.debugger.isActive { GoDebuggerPanel() }
            content
        }
    }

    @ViewBuilder private var content: some View {
        @Bindable var workspace = workspace

        switch pane {
        case .code:
            VStack(spacing: 0) {
                if !compactChrome {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(GopherForgeTheme.accent)
                    Text(workspace.selectedFile)
                        .font(.caption.monospaced().weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    if workspace.fileKind == .go && !workspace.selectedFile.hasPrefix("vendor/") {
                        Menu {
                            Button("Toggle breakpoint at caret") { workspace.debugger.toggle(file: workspace.selectedFile, line: workspace.debugger.caretLine) }
                            Button("Remove all breakpoints", role: .destructive) { workspace.debugger.removeAll() }
                        } label: {
                            Label("\(workspace.debugger.breakpointCount)", systemImage: "ladybug")
                                .font(.caption)
                                .frame(minWidth: 44, minHeight: 34)
                        }
                        .disabled(workspace.debugger.isActive)
                        .accessibilityIdentifier("debug.breakpointsMenu")
                        .accessibilityLabel("Breakpoints, \(workspace.debugger.breakpointCount). Tap a line number to toggle.")
                    }
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
                }
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
                    onCaretLineChange: { line, _ in workspace.debugger.caretLine = line },
                    focusRequest: focusRequest,
                    externalKeyboardAccessory: keyboardCommandsOnly,
                    onTextViewReady: onEditorReady,
                    breakpointLines: workspace.debugger.breakpoints[workspace.selectedFile] ?? [],
                    executionLine: workspace.debugger.pause?.point.file == workspace.selectedFile ? workspace.debugger.pause?.point.line : nil,
                    onToggleBreakpoint: workspace.fileKind == .go && !workspace.selectedFile.hasPrefix("vendor/") && !workspace.debugger.isActive ? { line in workspace.debugger.toggle(file: workspace.selectedFile, line: line) } : nil,
                    isReadOnly: workspace.debugger.isActive
                )
                .background(Color(.systemBackground))
            }
        case .problems:
            DiagnosticListView(diagnostics: workspace.lastResult?.diagnostics ?? [], onReveal: onRevealCode)
        case .output:
            OutputStreamView(
                result: workspace.lastResult,
                progress: workspace.runningStep,
                packageProblems: workspace.packageProblems,
                onRetryPackages: { Task { await workspace.retryPackageDownloads() } },
                siteURL: workspace.sitePreviewURL?.scheme == OfflinePreviewResources.scheme || (workspace.lastResult?.phase == .run && workspace.lastResult?.succeeded == true)
                    ? workspace.sitePreviewURL : nil,
                siteGeneration: workspace.siteGeneration,
                offlineFiles: workspace.project?.files[OfflineFrontendRecipe.path] != nil ? workspace.project?.files : nil
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
                    withAnimation { proxy.scrollTo(pane, anchor: .leading) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in
                    proxy.scrollTo(selection, anchor: .leading)
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

/// A named panel selector for the short, conventional phone toolbar.
struct WorkspacePaneMenu: View {
    @Binding var selection: WorkspacePane
    let panes: [WorkspacePane]

    var body: some View {
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
            HStack(spacing: 6) {
                Image(systemName: selection.systemImage)
                Text(selection.title)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.semibold)).fixedSize()
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityIdentifier("pane.more")
        .accessibilityLabel("Choose panel").accessibilityValue(selection.title)
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
