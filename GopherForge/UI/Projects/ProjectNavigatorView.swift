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

    /// Results grouped by file: the file once, the lines beneath it.
    ///
    /// A flat list showed `main.go` for its name and again for every line
    /// containing "main", which reads as the search stuttering rather than as
    /// one file that matched in several places.
    private var results: some View {
        List {
            if fileResults.isEmpty {
                ContentUnavailableView(
                    "Nothing matches",
                    systemImage: "magnifyingglass",
                    description: Text("No file name or line in this project contains \u{201C}\(query)\u{201D}.")
                )
            } else {
                ForEach(fileResults) { result in
                    Section {
                        ForEach(result.lines) { line in
                            Button {
                                open(result.path, at: line.number)
                            } label: {
                                SearchLineRow(line: line, query: query)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("search.line:\(result.path):\(line.number)")
                        }

                        if result.additionalLines > 0 {
                            // Said out loud rather than truncated silently: a
                            // capped list that looks complete is a lie.
                            Text("\(result.additionalLines) more in this file")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } header: {
                        Button {
                            open(result.path, at: result.lines.first?.number)
                        } label: {
                            SearchFileHeader(result: result, query: query)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.name:\(result.path)")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var fileResults: [ProjectFileSearch.FileResult] {
        ProjectFileSearch.results(query: query, in: workspace.project?.files ?? [:])
    }

    private func open(_ path: String, at line: Int?) {
        workspace.select(file: path, revealingLine: line)
        // The query travels with the selection so the editor can mark the same
        // occurrences the sidebar just showed.
        workspace.highlightQuery = query
        onSelect()
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
