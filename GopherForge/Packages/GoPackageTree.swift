import Foundation

/// How installed modules sit in the package list.
///
/// A module the project's own code imports is a root. A module that only
/// another package imports is nested under that package, so the list is the
/// dependency, not a flat dump of `go.mod`. The same nesting decides what
/// deleting a package may take with it: a dependency leaves only when nothing
/// that remains still imports it.
enum GoPackageTree {
    struct Node: Equatable, Identifiable, Sendable {
        let module: GoVendorWriter.InstalledModule
        let children: [Node]
        var id: String { module.path }
    }

    struct Row: Equatable, Identifiable, Sendable {
        let module: GoVendorWriter.InstalledModule
        let depth: Int
        let hasChildren: Bool
        /// Stable when the same dependency is nested under two packages.
        let id: String
    }

    struct Removal: Equatable, Sendable {
        let root: String
        /// Dependencies that nothing else still imports once `root` is gone.
        let exclusiveDependents: [String]

        var all: [String] { [root] + exclusiveDependents }
    }

    static func nodes(in files: [String: String]) -> [Node] {
        let graph = Graph(files: files)
        var visiting: Set<String> = []
        func node(for path: String) -> Node? {
            guard let module = graph.modules[path], visiting.insert(path).inserted else { return nil }
            defer { visiting.remove(path) }
            let children = graph.imports(of: path)
                .filter { !graph.isRoot($0) }
                .sorted()
                .compactMap { node(for: $0) }
            return Node(module: module, children: children)
        }
        return graph.modules.keys.filter(graph.isRoot).sorted {
            graph.modules[$0]?.isIndirect != graph.modules[$1]?.isIndirect
                ? graph.modules[$0]?.isIndirect == false
                : $0.localizedStandardCompare($1) == .orderedAscending
        }.compactMap { node(for: $0) }
    }

    static func rows(in files: [String: String], expanded: Set<String> = []) -> [Row] {
        rows(of: nodes(in: files), expanded: expanded)
    }

    /// Walks an already built package tree. Expanding a package must not parse
    /// every vendored file again.
    static func rows(of nodes: [Node], expanded: Set<String> = []) -> [Row] {
        var rows: [Row] = []
        func walk(_ nodes: [Node], depth: Int, parent: String) {
            for node in nodes {
                rows.append(
                    Row(
                        module: node.module,
                        depth: depth,
                        hasChildren: !node.children.isEmpty,
                        id: "\(parent)>\(node.module.path)"
                    )
                )
                if expanded.contains(node.module.path) {
                    walk(node.children, depth: depth + 1, parent: node.module.path)
                }
            }
        }
        walk(nodes, depth: 0, parent: "")
        return rows
    }

    /// What may leave with `modulePath`. A dependency is included only when
    /// every remaining importer is itself being removed, and the project's
    /// own code does not import it.
    static func removal(of modulePath: String, in files: [String: String]) -> Removal {
        let graph = Graph(files: files)
        var removing: Set<String> = [modulePath]
        var queue = [modulePath]
        while let current = queue.popLast() {
            for dependency in graph.imports(of: current) where !removing.contains(dependency) {
                if graph.usedByProject.contains(dependency) { continue }
                let importers = graph.importers(of: dependency)
                guard !importers.isEmpty, importers.isSubset(of: removing) else { continue }
                removing.insert(dependency)
                queue.append(dependency)
            }
        }
        return Removal(
            root: modulePath,
            exclusiveDependents: removing.subtracting([modulePath]).sorted()
        )
    }

    static func remove(_ removal: Removal, from files: [String: String]) -> [String: String] {
        removal.all.reduce(files) { files, path in
            GoVendorWriter.remove(modulePath: path, from: files)
        }
    }

    // MARK: - Graph

    private struct Graph {
        let modules: [String: GoVendorWriter.InstalledModule]
        let usedByProject: Set<String>
        private let importsOf: [String: Set<String>]
        private let importersOf: [String: Set<String>]

        func imports(of module: String) -> Set<String> { importsOf[module] ?? [] }
        func importers(of module: String) -> Set<String> { importersOf[module] ?? [] }

        func isRoot(_ path: String) -> Bool {
            if usedByProject.contains(path) { return true }
            // Nested when some other package imports it and the project does not,
            // whether or not go.mod still says // indirect.
            return importers(of: path).isEmpty
        }

        init(files: [String: String]) {
            let listed = GoVendorWriter.installedModules(in: files)
            modules = Dictionary(uniqueKeysWithValues: listed.map { ($0.path, $0) })
            let paths = Set(modules.keys)

            func owner(of importPath: String) -> String? {
                paths.filter { importPath == $0 || importPath.hasPrefix($0 + "/") }
                    .max { $0.count < $1.count }
            }
            func owner(ofVendorFile path: String) -> String? {
                let relative = path.dropFirst((GoVendorWriter.vendorDirectory + "/").count)
                let directory = relative.split(separator: "/").dropLast().joined(separator: "/")
                return owner(of: String(directory))
            }

            var used: Set<String> = []
            var imports: [String: Set<String>] = [:]
            for (path, text) in files where path.hasSuffix(".go") {
                let imported = Set(GoSourceHeader.parse(text).imports.compactMap(owner(of:)))
                if GoVendorWriter.isVendoredPath(path) {
                    guard let module = owner(ofVendorFile: path) else { continue }
                    imports[module, default: []].formUnion(imported.subtracting([module]))
                } else {
                    used.formUnion(imported)
                }
            }
            usedByProject = used
            importsOf = imports
            var importers: [String: Set<String>] = [:]
            for (module, dependencies) in imports {
                for dependency in dependencies {
                    importers[dependency, default: []].insert(module)
                }
            }
            importersOf = importers
        }
    }
}
