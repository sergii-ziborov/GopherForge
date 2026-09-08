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
    /// The dock's height on iPad, dragged at the seam and remembered. 280 fits
    /// a handful of diagnostics; someone reading a long test log wants more,
    /// someone writing wants the editor back, and neither should have to take
    /// whatever was chosen for them.
    @AppStorage("dockHeight") private var dockHeight: Double = 280
    @State private var dockDragStart: Double?
    private let dockHeightRange: ClosedRange<Double> = 120...640
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

            dockResizeHandle

            VStack(spacing: 0) {
                WorkspacePanePicker(selection: $dockPane, panes: WorkspacePane.dockPanes)
                Divider()
                WorkspacePaneContent(pane: dockPane, terminal: terminal, fontSize: fontSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: dockHeight)
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
            HStack(spacing: 0) {
                // The file tree stays on screen beside the code, narrow.
                //
                // It used to live only in the drawer, which meant switching
                // files was: tap Files, read the list, tap a file, watch the
                // drawer close. Three taps and a covered editor to do the thing
                // a project does most. 132 points fits a Go file name at
                // footnote size with the extension intact, and the drawer stays
                // for search and for reaching deep paths.
                if pane == .code {
                    ProjectNavigatorView(isNarrow: true)
                        .frame(width: 132)
                        .background(Color(.secondarySystemBackground))
                    Divider()
                }

                paneStack(terminal: terminal)
            }

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

    /// The seam between editor and dock. Dragging it up gives the dock room,
    /// dragging it down gives it back to the code; the grabber says it moves.
    private var dockResizeHandle: some View {
        ZStack {
            Divider()
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 44, height: 5)
        }
        .frame(height: 14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if dockDragStart == nil { dockDragStart = dockHeight }
                    // Dragging up (negative translation) makes the dock taller.
                    let proposed = (dockDragStart ?? dockHeight) - value.translation.height
                    dockHeight = min(max(proposed, dockHeightRange.lowerBound), dockHeightRange.upperBound)
                }
                .onEnded { _ in dockDragStart = nil }
        )
        .accessibilityIdentifier(AccessibilityID.dockResizeHandle)
        .accessibilityLabel("Resize dock")
        .accessibilityAdjustableAction { direction in
            let step: Double = 40
            switch direction {
            case .increment: dockHeight = min(dockHeight + step, dockHeightRange.upperBound)
            case .decrement: dockHeight = max(dockHeight - step, dockHeightRange.lowerBound)
            @unknown default: break
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

            WorkspacePaneContent(
                pane: pane,
                terminal: terminal,
                fontSize: fontSize,
                onRevealCode: { withAnimation(.easeOut(duration: 0.2)) { pane = .code } }
            )
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
    // Format leads: gofmt is bundled and was wired to a phase from the start,
    // and until now nothing on screen could invoke it — a working formatter
    // with no button. It is the one action here that changes the file rather
    // than reporting on it, and it goes first so the row reads tidy, build,
    // test, run.
    static let primaryPhases: [CompilationResult.Phase] = [.format, .build, .test, .run]

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
/// A working compiler is not news. Saying "Bundled Go 1.27.1" on every screen
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
                .foregroundStyle(GopherForgeTheme.warning)
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
