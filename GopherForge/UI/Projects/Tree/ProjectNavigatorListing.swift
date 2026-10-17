import Foundation

/// One folder or file in the navigator.
///
/// Children are the contents of a folder. A file's children are empty. The
/// name is the last path component, so a folder displays as `skills` rather
/// than `.agents/skills/release`.
struct ProjectFileNode: Equatable, Identifiable, Sendable {
    let name: String
    let path: String
    let isFolder: Bool
    let children: [ProjectFileNode]

    var id: String { (isFolder ? "d:" : "f:") + path }
}

/// A node flattened for a list, with the depth the row indents by.
struct ProjectNavigatorRow: Equatable, Identifiable, Sendable {
    let name: String
    let path: String
    let isFolder: Bool
    let depth: Int

    var id: String { (isFolder ? "d:" : "f:") + path }
}

/// The project's own files as a directory tree, with `vendor/` left out.
///
/// The project stores files as a flat path map, which is what the compiler
/// wants. The navigator is the place that puts those paths back into the
/// folders they came from.
enum ProjectNavigatorListing {
    static func tree(in files: [String: String]) -> [ProjectFileNode] {
        var folders: [String: Set<String>] = [:]
        var filePaths: [String: [String]] = [:]

        func ensureFolder(_ directory: String) {
            guard !directory.isEmpty else { return }
            let parts = directory.split(separator: "/").map(String.init)
            var parent = ""
            for part in parts {
                folders[parent, default: []].insert(part)
                parent = parent.isEmpty ? part : parent + "/" + part
                if folders[parent] == nil { folders[parent] = [] }
            }
        }

        for path in files.keys where !GoVendorWriter.isVendoredPath(path) {
            let name = path.split(separator: "/").last.map(String.init) ?? path
            let directory = GoPackageGraph.directory(of: path)
            if name == GopherForgeProject.folderMarker {
                ensureFolder(directory)
                continue
            }
            ensureFolder(directory)
            filePaths[directory, default: []].append(path)
        }

        func nodes(in directory: String) -> [ProjectFileNode] {
            let folderNodes = (folders[directory] ?? []).map { name in
                let path = directory.isEmpty ? name : directory + "/" + name
                return ProjectFileNode(
                    name: name,
                    path: path,
                    isFolder: true,
                    children: nodes(in: path)
                )
            }
            let files = (filePaths[directory] ?? []).map { path in
                ProjectFileNode(
                    name: path.split(separator: "/").last.map(String.init) ?? path,
                    path: path,
                    isFolder: false,
                    children: []
                )
            }
            return (folderNodes + files).sorted { lhs, rhs in
                if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }

        return nodes(in: "")
    }

    /// Directories from the project root down to the file, not including the file.
    static func ancestors(of path: String) -> Set<String> {
        let parts = path.split(separator: "/").dropLast().map(String.init)
        var ancestors: Set<String> = []
        var current = ""
        for part in parts {
            current = current.isEmpty ? part : current + "/" + part
            ancestors.insert(current)
        }
        return ancestors
    }

    /// A folder is open when it leads to the file on screen, or the reader opened
    /// it, and they have not closed it since.
    static func isOpen(
        _ folder: String,
        revealing path: String?,
        expanded: Set<String>,
        collapsed: Set<String>
    ) -> Bool {
        if collapsed.contains(folder) { return false }
        if expanded.contains(folder) { return true }
        guard let path else { return false }
        return ancestors(of: path).contains(folder)
    }

    static func rows(
        in files: [String: String],
        revealing path: String? = nil,
        expanded: Set<String> = [],
        collapsed: Set<String> = []
    ) -> [ProjectNavigatorRow] {
        var rows: [ProjectNavigatorRow] = []
        func walk(_ nodes: [ProjectFileNode], depth: Int) {
            for node in nodes {
                rows.append(
                    ProjectNavigatorRow(
                        name: node.name,
                        path: node.path,
                        isFolder: node.isFolder,
                        depth: depth
                    )
                )
                guard node.isFolder,
                      isOpen(node.path, revealing: path, expanded: expanded, collapsed: collapsed)
                else { continue }
                walk(node.children, depth: depth + 1)
            }
        }
        walk(tree(in: files), depth: 0)
        return rows
    }
}
