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

                    if !result.artifacts.isEmpty {
                        DrawnImagesSection(images: result.artifacts.images)
                    }
                    if !result.stdout.isEmpty {
                        StreamSection(title: "stdout", text: result.stdout, tint: .primary)
                    }
                    if !result.stderr.isEmpty {
                        StreamSection(title: "stderr", text: result.stderr, tint: .red)
                    }
                    if result.stdout.isEmpty, result.stderr.isEmpty, result.artifacts.isEmpty {
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

/// What the program drew.
///
/// A Go program that writes a PNG has produced a result as real as one that
/// printed a line, and until now the app threw it away with the sandbox.
private struct DrawnImagesSection: View {
    let images: [GoProgramArtifacts.Image]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                images.count == 1 ? "Drawn" : "Drawn (\(images.count))",
                systemImage: "photo"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(images) { image in
                        VStack(alignment: .leading, spacing: 4) {
                            if let rendered = UIImage(data: image.data) {
                                Image(uiImage: rendered)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    // A checkerboard behind it, because a PNG
                                    // with transparency on a dark background
                                    // otherwise looks like a missing image.
                                    .background(TransparencyChecker())
                                    .frame(maxWidth: 240, maxHeight: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                                    )
                            } else {
                                Label("Not an image this device can decode", systemImage: "questionmark.square")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(image.name) · \(ByteCountFormatter.string(fromByteCount: Int64(image.data.count), countStyle: .file))")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("output.image.\(image.name)")
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.outputImages)
    }
}

/// The usual grey squares, so transparency reads as transparency.
private struct TransparencyChecker: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 8
            for row in 0..<Int(size.height / square + 1) {
                for column in 0..<Int(size.width / square + 1) {
                    guard (row + column).isMultiple(of: 2) else { continue }
                    context.fill(
                        Path(CGRect(
                            x: CGFloat(column) * square,
                            y: CGFloat(row) * square,
                            width: square,
                            height: square
                        )),
                        with: .color(Color(.systemGray4))
                    )
                }
            }
        }
        .background(Color(.systemGray5))
    }
}
