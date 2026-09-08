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
    /// The pinned column on iPhone, which is too narrow for a search field.
    /// Searching stays in the drawer, where there is room to read a result.
    var isNarrow = false

    var body: some View {
        VStack(spacing: 0) {
            if !isNarrow {
                ProjectSearchField(query: $query)
                Divider()
            }

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
        Group {
            if isNarrow {
                // Plain and tight. The sidebar style's grouped insets and
                // rounded cards cost more width than the names themselves at
                // this size, and wrapped "g o . m o d" one letter per line.
                List {
                    ForEach(groups, id: \.directory) { group in
                        Section {
                            rows(in: group)
                                .listRowInsets(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 4))
                        } header: {
                            Text(group.title)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                List {
                    ForEach(groups, id: \.directory) { group in
                        Section(group.title) { rows(in: group) }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func rows(in group: (directory: String, title: String, paths: [String])) -> some View {
        ForEach(group.paths, id: \.self) { path in
            Button {
                workspace.select(file: path)
                onSelect()
            } label: {
                ProjectFileRow(
                    path: path,
                    isSelected: workspace.selectedFile == path,
                    detail: nil,
                    isNarrow: isNarrow
                )
            }
            .buttonStyle(.plain)
            // The pinned column and the drawer can both be on screen on a
            // phone, and one identifier on two buttons is an ambiguous match
            // that fails every tap. The column gets its own; `file.<path>`
            // stays the drawer's and the iPad tree's.
            .accessibilityIdentifier(
                isNarrow ? AccessibilityID.columnFile(path) : AccessibilityID.file(path)
            )
        }
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
