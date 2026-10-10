import SwiftUI

/// One phase button, so the toolbar cannot drift from what the model supports.
struct PhaseButton: View {
    // Format is last, and the order is not cosmetic. On an 11-inch iPad the
    // top tab bar shares the row with these, four do not fit, and SwiftUI
    // folds the tail of the group into a "…" menu. With Format first, what
    // folded away was Test and Run — the two actions the app exists for. Now
    // the one that folds on a narrow iPad is Format, still one tap away in
    // the menu; on every wider screen all four show.
    //
    // gofmt itself is bundled and was wired to a phase from the start; until
    // now nothing on screen could invoke it — a working formatter with no
    // button.
    static let primaryPhases: [CompilationResult.Phase] = WorkspaceToolbarActions.primaryPhases

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
struct WorkspaceStatusStrip: View {
    let status: ToolchainStatus

    var body: some View {
        if !status.isReady {
            MissingToolchainRow(status: status)
                .background(.bar)
                .accessibilityIdentifier(AccessibilityID.toolchainBanner)
        }
    }
}

/// Why every build action is unavailable, in the toolchain's own words.
struct MissingToolchainRow: View {
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
