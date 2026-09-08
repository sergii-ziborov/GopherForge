import SwiftUI

/// Compiler and vet findings, with the source line each one points at.
struct DiagnosticListView: View {
    @Environment(WorkspaceModel.self) private var workspace
    let diagnostics: [GoDiagnostic]
    /// Called after a row has moved the editor, so a phone can switch to the
    /// Code tab — on iPad the editor is already on screen and this is a no-op.
    var onReveal: () -> Void = {}

    var body: some View {
        if diagnostics.isEmpty {
            EmptyDockMessage(
                systemImage: "checkmark.circle",
                title: "No problems",
                message: "Build, vet or test to see what the toolchain says."
            ,
                tint: WorkspacePane.problems.tint
            )
        } else {
            List(diagnostics) { diagnostic in
                // The row goes to the line. A list of errors that only
                // describes where they are leaves the person to find each one
                // by hand, which on a phone means leaving this tab, opening the
                // file, and scrolling by line number from memory.
                Button {
                    reveal(diagnostic)
                } label: {
                    row(diagnostic)
                }
                .buttonStyle(.plain)
                .disabled(!canReveal(diagnostic))
                .accessibilityIdentifier(AccessibilityID.diagnostic(testKey(diagnostic)))
                .accessibilityHint(canReveal(diagnostic) ? "Opens the line in the editor" : "")
            }
            .listStyle(.plain)
        }
    }

    private func row(_ diagnostic: GoDiagnostic) -> some View {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: diagnostic.isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(diagnostic.isBlocking ? Color.red : GopherForgeTheme.warning)
                        Text(diagnostic.message)
                            .font(.callout)
                            .textSelection(.enabled)
                    }

                    if let span = diagnostic.span {
                        Text("\(span.fileName):\(span.line):\(span.column)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        if !span.sourceLine.isEmpty {
                            Text(span.sourceLine)
                                .font(.caption.monospaced())
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    if diagnostic.origin == .vet {
                        Text("go vet · does not block the build")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
    }

    /// Stable across runs, unlike the UUID: a test can find "main.go:10".
    private func testKey(_ diagnostic: GoDiagnostic) -> String {
        diagnostic.span.map { "\($0.fileName):\($0.line)" } ?? diagnostic.id.uuidString
    }

    /// Only a diagnostic that names a file this project actually has. The
    /// toolchain can report against a generated or vendored path, and jumping
    /// to a file that is not in the editor would blank it.
    private func canReveal(_ diagnostic: GoDiagnostic) -> Bool {
        guard let span = diagnostic.span else { return false }
        return workspace.project?.files[span.fileName] != nil
    }

    private func reveal(_ diagnostic: GoDiagnostic) {
        guard canReveal(diagnostic), let span = diagnostic.span else { return }
        workspace.select(file: span.fileName, revealingLine: span.line)
        onReveal()
    }
}

/// Shared empty state so every dock tab says something useful rather than
/// showing a blank panel.
struct EmptyDockMessage: View {
    let systemImage: String
    let title: String
    let message: String
    /// The pane's own colour, so an empty panel still says which one it is.
    var tint: Color = .secondary

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.12), in: Circle())
            Text(title).font(.callout.weight(.medium))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
