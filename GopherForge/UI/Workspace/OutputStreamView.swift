import SwiftUI

/// The program's own stdout and stderr, kept separate.
///
/// Mixing them is how people lose track of which line the program printed and
/// which line the runtime did.
struct OutputStreamView: View {
    let result: CompilationResult?

    var body: some View {
        guard let result else {
            return AnyView(
                EmptyDockMessage(
                    systemImage: "terminal",
                    title: "Nothing has run yet",
                    message: "Run the program to see its output here."
                )
            )
        }

        return AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ResultSummaryRow(result: result)

                    if !result.stdout.isEmpty {
                        StreamSection(title: "stdout", text: result.stdout, tint: .primary)
                    }
                    if !result.stderr.isEmpty {
                        StreamSection(title: "stderr", text: result.stderr, tint: .red)
                    }
                    if result.stdout.isEmpty, result.stderr.isEmpty {
                        Text("The program produced no output.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        )
    }
}

private struct ResultSummaryRow: View {
    let result: CompilationResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(GopherForgeTheme.statusColor(succeeded: result.succeeded))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.detail).font(.callout)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var subtitle: String {
        let phase = GopherForgeTheme.label(for: result.phase)
        let parts = result.duration.components
        let milliseconds = Int(Double(parts.seconds) * 1_000
            + Double(parts.attoseconds) / 1_000_000_000_000_000)
        return "\(phase) · \(milliseconds) ms"
    }
}

private struct StreamSection: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption.monospaced())
                .foregroundStyle(tint)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
