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
    @State private var isShowingFiles = false

    var body: some View {
        VStack(spacing: 0) {
            ToolchainBanner(status: workspace.toolchain)

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
        .sheet(isPresented: $isShowingFiles) {
            NavigationStack {
                ProjectFileTreeView()
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            if terminal == nil { terminal = ProjectTerminalSession(workspace: workspace) }
        }
    }

    // MARK: - Layouts

    private func regularLayout(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ProjectFileTreeView()
                    .frame(width: 240)
                Divider()
                WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
            }

            Divider()

            VStack(spacing: 0) {
                WorkspacePanePicker(selection: $dockPane, panes: WorkspacePane.dockPanes)
                    .padding(8)
                Divider()
                WorkspacePaneContent(pane: dockPane, terminal: terminal, fontSize: fontSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 280)
            .background(Color(.secondarySystemBackground))
        }
    }

    private func compactLayout(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            // The switcher sits directly under the banner rather than at the
            // bottom: on a phone the keyboard owns the bottom of the screen.
            ScrollView(.horizontal, showsIndicators: false) {
                WorkspacePanePicker(selection: $pane, panes: WorkspacePane.allCases)
                    .frame(minWidth: 520)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))

            Divider()

            WorkspacePaneContent(pane: pane, terminal: terminal, fontSize: fontSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if horizontalSizeClass == .compact {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingFiles = true
                } label: {
                    Label("Files", systemImage: "sidebar.leading")
                }
            }
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

/// Says what compiler is present, and says it plainly when none is.
private struct ToolchainBanner: View {
    let status: ToolchainStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(status.isReady ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.label).font(.footnote.weight(.medium))
                Text(status.detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .accessibilityIdentifier(AccessibilityID.toolchainBanner)
    }
}
