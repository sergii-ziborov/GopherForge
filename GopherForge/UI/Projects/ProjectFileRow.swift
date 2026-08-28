import SwiftUI

/// One row in the navigator: an icon that says what the file is for, its name,
/// and — in search results — the line that matched.
struct ProjectFileRow: View {
    let path: String
    let isSelected: Bool
    /// A search hit's line and text, or nil in the plain tree.
    let detail: String?

    private var badge: SourceFileBadge { SourceFileBadge.of(path: path) }
    private var name: String { path.split(separator: "/").last.map(String.init) ?? path }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            // Fixed width so names line up whatever symbol each row gets; a
            // ragged left edge is harder to scan than no icons at all.
            Image(systemName: badge.systemImage)
                .foregroundStyle(badge.tint)
                .font(.callout)
                .frame(width: 20, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                if let detail {
                    Text(detail)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if path.contains("/") {
                    // The directory only in the tree, where a row's section
                    // already says it, and always in results, where it does not.
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(badge.accessibilityDescription)")
    }
}

/// The search field above the tree.
struct ProjectSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.footnote)
            TextField("Name or contents", text: $query)
                .textFieldStyle(.plain)
                .font(.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier(AccessibilityID.fileSearch)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// The header of one file's search results: what it is, and how it matched.
struct SearchFileHeader: View {
    let result: ProjectFileSearch.FileResult
    let query: String

    private var badge: SourceFileBadge { SourceFileBadge.of(path: result.path) }
    private var name: String {
        result.path.split(separator: "/").last.map(String.init) ?? result.path
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: badge.systemImage)
                .foregroundStyle(badge.tint)
                .font(.caption)
                .frame(width: 18)
                .accessibilityHidden(true)

            // The name is marked too, since a name match is why some files are
            // in the list at all.
            HighlightedText(text: name, query: result.matchesName ? query : "", font: .caption.weight(.semibold))
                .lineLimit(1)

            Text(result.summary)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.path), \(result.summary)")
    }
}

/// One matched line, with the query marked inside it.
struct SearchLineRow: View {
    let line: ProjectFileSearch.Line
    let query: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(line.number)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                // Fixed width so the code starts at the same x on every row;
                // ragged code is much harder to scan than ragged numbers.
                .frame(width: 30, alignment: .trailing)

            HighlightedText(text: line.snippet, query: query)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Line \(line.number), \(line.snippet)")
    }
}
