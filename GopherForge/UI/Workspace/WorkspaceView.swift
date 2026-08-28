import SwiftUI

/// The Build side.
///
/// Two layouts, because the right answer differs by device. On iPad there is
/// room for the file tree, the editor and a dock at once. On iPhone a split
/// gives a cramped editor above a cramped panel and serves neither, so the
/// workspace becomes full-height tabs with the switcher at the top, where a
/// thumb reaches it.
struct WorkspaceView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("editorFontSize") private var fontSize: Double = 14

    @State private var pane: WorkspacePane = .code
    @State private var dockPane: WorkspacePane = .problems
    @State private var terminal: ProjectTerminalSession?
    /// The navigator's state. On iPad it is a column that can be collapsed; on
    /// iPhone it is a drawer over the editor. One flag, because it is the same
    /// question — is the file list showing — asked of two layouts.
    @AppStorage("navigatorVisible") private var isNavigatorVisible = true
    @State private var isDrawerOpen = false

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceStatusStrip(status: workspace.toolchain, progress: workspace.runningStep)

            if let terminal {
                if horizontalSizeClass == .regular {
                    regularLayout(terminal: terminal)
                } else {
                    compactLayout(terminal: terminal)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(workspace.project?.name ?? "Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task {
            if terminal == nil { terminal = ProjectTerminalSession(workspace: workspace) }
        }
        // A finished run opens the pane that answers it. Keyed on the
        // generation rather than the result, so running the same thing twice
        // still moves.
        .onChange(of: workspace.resultGeneration) {
            guard let result = workspace.lastResult,
                  let destination = WorkspacePane.afterRun(result)
            else {
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                if horizontalSizeClass == .regular {
                    // The iPad keeps the editor on screen, so only the dock
                    // moves and the code the person was reading stays put.
                    dockPane = destination
                } else {
                    pane = destination
                }
            }
        }
    }

    // MARK: - Layouts

    private func regularLayout(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if isNavigatorVisible {
                    ProjectNavigatorView()
                        .frame(width: 260)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }
                WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
            }

            Divider()

            VStack(spacing: 0) {
                WorkspacePanePicker(selection: $dockPane, panes: WorkspacePane.dockPanes)
                Divider()
                WorkspacePaneContent(pane: dockPane, terminal: terminal, fontSize: fontSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 280)
            .background(Color(.secondarySystemBackground))
        }
    }

    /// The drawer, over the editor rather than instead of it.
    ///
    /// A sheet covered the code someone was reading in order to let them choose
    /// what to read. This keeps the editor on screen behind it, and a tap on
    /// the dimmed part puts it away — which is what everything else on the
    /// phone does.
    private func compactLayout(terminal: ProjectTerminalSession) -> some View {
        ZStack(alignment: .leading) {
            paneStack(terminal: terminal)

            if isDrawerOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = false } }
                    .accessibilityLabel("Close files")
                    .accessibilityAddTraits(.isButton)

                ProjectNavigatorView { withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = false } }
                    .frame(maxWidth: 320)
                    .shadow(radius: 12)
                    .transition(.move(edge: .leading))
            }
        }
    }

    private func paneStack(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            // The switcher sits at the top rather than the bottom: on a phone
            // the keyboard owns the bottom of the screen. It scrolls, because
            // six tabs do not fit across a phone at any readable size.
            WorkspacePanePicker(selection: $pane, panes: WorkspacePane.allCases)
                .background(Color(.secondarySystemBackground))

            Divider()

            WorkspacePaneContent(pane: pane, terminal: terminal, fontSize: fontSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if horizontalSizeClass == .compact {
                        isDrawerOpen.toggle()
                    } else {
                        isNavigatorVisible.toggle()
                    }
                }
            } label: {
                Label("Files", systemImage: "sidebar.leading")
            }
            .accessibilityIdentifier(AccessibilityID.filesToggle)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            ForEach(PhaseButton.primaryPhases, id: \.self) { phase in
                PhaseButton(phase: phase)
            }
        }
    }
}

/// One phase button, so the toolbar cannot drift from what the model supports.
private struct PhaseButton: View {
    static let primaryPhases: [CompilationResult.Phase] = [.build, .test, .run]

    @Environment(WorkspaceModel.self) private var workspace
    let phase: CompilationResult.Phase

    var body: some View {
        Button {
            Task { await workspace.run(phase) }
        } label: {
            if workspace.runningPhase == phase {
                ProgressView()
            } else {
                Label(
                    GopherForgeTheme.label(for: phase),
                    systemImage: GopherForgeTheme.systemImage(for: phase)
                )
            }
        }
        .disabled(!workspace.canRun)
        .accessibilityIdentifier(AccessibilityID.phase(phase))
    }
}

/// The strip above the editor, which is usually nothing at all.
///
/// A working compiler is not news. Saying "Bundled Go 1.24.2" on every screen
/// spends a line of a phone's height on a fact that does not change and that
/// Settings already reports. So this appears only when it has something to
/// say: that no compiler is staged, which is the only explanation for the
/// disabled buttons, or that a build is running, which is the difference
/// between working and stuck.
private struct WorkspaceStatusStrip: View {
    let status: ToolchainStatus
    let progress: GoBuildProgress?

    var body: some View {
        if !status.isReady || progress != nil {
            VStack(spacing: 0) {
                if !status.isReady { MissingToolchainRow(status: status) }
                if let progress { BuildProgressRow(progress: progress) }
            }
            .background(.bar)
            .accessibilityIdentifier(AccessibilityID.toolchainBanner)
        }
    }
}

/// Why every build action is unavailable, in the toolchain's own words.
private struct MissingToolchainRow: View {
    let status: ToolchainStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.label).font(.footnote.weight(.medium))
                Text(status.detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// One line naming the step, and a bar showing how much of the plan is left.
private struct BuildProgressRow: View {
    let progress: GoBuildProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(progress.summary)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .accessibilityIdentifier(AccessibilityID.buildProgress)
        .accessibilityLabel("Building: \(progress.summary)")
        .transition(.opacity)
    }
}
