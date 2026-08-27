import SwiftUI

/// The Build side: file tree, editor and the result dock.
struct WorkspaceView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @State private var isShowingFiles = false

    var body: some View {
        @Bindable var workspace = workspace

        VStack(spacing: 0) {
            ToolchainBanner(status: workspace.toolchain)

            HStack(spacing: 0) {
                if horizontalSizeClass == .regular {
                    ProjectFileTreeView()
                        .frame(width: 240)
                    Divider()
                }

                SyntaxCodeEditor(
                    text: $workspace.editorText,
                    fileKind: workspace.fileKind,
                    fontSize: fontSize,
                    markedLines: workspace.markedLines
                )
                .accessibilityIdentifier(AccessibilityID.editor)
            }

            Divider()
            BuildDockView()
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
    }

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
