import SwiftUI

/// One project in the library.
///
/// Four facts, in the order someone scanning for a project needs them: what it
/// is called, what they said it was, how big it is, and how it last built. The
/// star is on the left where the eye lands first, because in a list of thirty
/// the starred ones are what people are looking for.
struct ProjectLibraryRow: View {
    let item: ProjectLibraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.favorite ? "star.fill" : "shippingbox.fill")
                .font(.callout)
                .foregroundStyle(item.favorite ? GopherForgeTheme.warning : GopherForgeTheme.accent)
                .frame(width: 30, height: 30)
                .background(
                    (item.favorite ? GopherForgeTheme.warning : GopherForgeTheme.accentSolid)
                        .opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.project.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !item.tagList.isEmpty {
                    tagRow
                }

                // The last build as a chip rather than a bare tick: "3 tests"
                // and "build failed" are different facts, and a tick says
                // neither of them.
                BuildOutcomeChip(record: item.lastBuild)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.project.name)
        .accessibilityValue(item.favorite ? "Starred, in \(item.folderLabel)" : "In \(item.folderLabel)")
    }

    private var tagRow: some View {
        HStack(spacing: 5) {
            ForEach(item.tagList.prefix(4), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(GopherForgeTheme.accentWash(0.12), in: Capsule())
                    .foregroundStyle(GopherForgeTheme.accent)
            }
            if item.tagList.count > 4 {
                Text("+\(item.tagList.count - 4)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let module = item.project.module { parts.append(module.modulePath) }
        parts.append("\(item.project.goFileCount) Go files")
        if item.project.testFileCount > 0 {
            parts.append("\(item.project.testFileCount) test files")
        }
        return parts.joined(separator: " · ")
    }
}
