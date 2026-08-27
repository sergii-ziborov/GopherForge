import SwiftUI

/// The file list, grouped by package directory.
///
/// Grouping by directory rather than showing a flat list is the point: in Go a
/// directory *is* a package, so the tree teaches the structure while you use it.
struct ProjectFileTreeView: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        List {
            ForEach(groups, id: \.directory) { group in
                Section(group.title) {
                    ForEach(group.paths, id: \.self) { path in
                        Button {
                            workspace.select(file: path)
                        } label: {
                            row(for: path)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.file(path))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(for path: String) -> some View {
        let badge = SourceFileBadge.of(path: path)
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let isSelected = workspace.selectedFile == path

        return HStack(spacing: 8) {
            // Fixed width so the names line up whatever symbol each row gets;
            // a ragged left edge is harder to scan than no icons at all.
            Image(systemName: badge.systemImage)
                .foregroundStyle(badge.tint)
                .font(.callout)
                .frame(width: 20, alignment: .center)
                .accessibilityHidden(true)
            Text(name)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(badge.accessibilityDescription)")
    }

    private var groups: [(directory: String, title: String, paths: [String])] {
        let files = workspace.project?.files.keys.sorted() ?? []
        let grouped = Dictionary(grouping: files) { path -> String in
            let components = path.split(separator: "/").dropLast()
            return components.isEmpty ? "." : components.joined(separator: "/")
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { directory, paths in
                (
                    directory: directory,
                    title: directory == "." ? "module root" : directory,
                    paths: paths.sorted()
                )
            }
    }
}
