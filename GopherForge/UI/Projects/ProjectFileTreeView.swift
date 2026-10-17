import SwiftUI

/// The file list as a nested tree.
///
/// A directory is a package in Go, and it is also a folder. The row shows the
/// folder's own name, indented under its parent, rather than the whole path.
struct ProjectFileTreeView: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        List {
            ForEach(rows) { row in
                if row.isFolder {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.callout)
                            .frame(width: 20, alignment: .center)
                            .accessibilityHidden(true)
                        Text(row.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(.leading, CGFloat(row.depth) * 14)
                    .accessibilityLabel("Folder \(row.path)")
                } else {
                    Button {
                        workspace.select(file: row.path)
                    } label: {
                        fileLabel(for: row)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, CGFloat(row.depth) * 14)
                    .accessibilityIdentifier(AccessibilityID.file(row.path))
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func fileLabel(for row: ProjectNavigatorRow) -> some View {
        let badge = SourceFileBadge.of(path: row.path)
        let isSelected = workspace.selectedFile == row.path

        return HStack(spacing: 8) {
            Image(systemName: badge.systemImage)
                .foregroundStyle(badge.tint)
                .font(.callout)
                .frame(width: 20, alignment: .center)
                .accessibilityHidden(true)
            Text(row.name)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(badge.accessibilityDescription)")
    }

    private var rows: [ProjectNavigatorRow] {
        ProjectNavigatorListing.rows(in: workspace.project?.files ?? [:])
    }
}
