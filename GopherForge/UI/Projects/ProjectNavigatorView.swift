import SwiftUI

/// The file navigator: a searchable tree that lives beside the editor rather
/// than on top of it.
///
/// It was a sheet, and a sheet is the wrong shape for this. Choosing a file is
/// not a decision you make once and dismiss — it is something you do while
/// reading code, and a sheet covers the code you were reading. Here it is a
/// column on iPad and a drawer on iPhone, and either way the editor stays
/// where it was.
struct ProjectNavigatorView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var query = ""
    /// Called after a file is chosen, so a drawer can close itself.
    var onSelect: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ProjectSearchField(query: $query)
            Divider()

            if query.isEmpty {
                tree
            } else {
                results
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Tree

    private var tree: some View {
        List {
            ForEach(groups, id: \.directory) { group in
                Section(group.title) {
                    ForEach(group.paths, id: \.self) { path in
                        Button {
                            workspace.select(file: path)
                            onSelect()
                        } label: {
                            ProjectFileRow(
                                path: path,
                                isSelected: workspace.selectedFile == path,
                                detail: nil
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.file(path))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Search

    private var results: some View {
        List {
            if matches.isEmpty {
                ContentUnavailableView(
                    "Nothing matches",
                    systemImage: "magnifyingglass",
                    description: Text("No file name or line in this project contains “\(query)”.")
                )
            } else {
                Section("\(matches.count) result\(matches.count == 1 ? "" : "s")") {
                    ForEach(matches) { match in
                        Button {
                            workspace.select(file: match.path, revealingLine: match.lineNumber)
                            onSelect()
                        } label: {
                            ProjectFileRow(
                                path: match.path,
                                isSelected: workspace.selectedFile == match.path,
                                detail: detail(for: match)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.\(match.id)")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var matches: [ProjectFileSearch.Match] {
        ProjectFileSearch.matches(query: query, in: workspace.project?.files ?? [:])
    }

    private func detail(for match: ProjectFileSearch.Match) -> String? {
        if case let .content(line, snippet) = match.kind { return "\(line): \(snippet)" }
        return nil
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
                    // A directory is a package in Go, so the tree teaches the
                    // structure while it is used.
                    title: directory == "." ? "module root" : directory,
                    paths: paths.sorted()
                )
            }
    }
}
