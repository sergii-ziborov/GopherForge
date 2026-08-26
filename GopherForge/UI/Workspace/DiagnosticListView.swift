import SwiftUI

/// Compiler and vet findings, with the source line each one points at.
struct DiagnosticListView: View {
    let diagnostics: [GoDiagnostic]

    var body: some View {
        if diagnostics.isEmpty {
            EmptyDockMessage(
                systemImage: "checkmark.circle",
                title: "No problems",
                message: "Build, vet or test to see what the toolchain says."
            )
        } else {
            List(diagnostics) { diagnostic in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: diagnostic.isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(diagnostic.isBlocking ? Color.red : Color.orange)
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
            }
            .listStyle(.plain)
        }
    }
}

/// Shared empty state so every dock tab says something useful rather than
/// showing a blank panel.
struct EmptyDockMessage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
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
