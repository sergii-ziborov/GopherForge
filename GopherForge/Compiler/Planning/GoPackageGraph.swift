import Foundation

/// One package inside the user's module.
struct GoPackage: Equatable {
    /// Import path, for example `playground` or `playground/mathx`.
    let importPath: String
    /// Project-relative directory, empty for the module root.
    let directory: String
    /// The package clause its files agree on.
    let name: String
    /// True for a package under `vendor/`, which is compiled like any other
    /// but is never the module's own entry point.
    let isVendored: Bool
    let goFiles: [String]
    /// `_test.go` files that share the package clause and are compiled into it.
    let internalTestFiles: [String]
    /// `_test.go` files declaring `package <name>_test`, compiled separately.
    let externalTestFiles: [String]
    let imports: Set<String>
    let testImports: Set<String>

    var isMain: Bool { name == "main" && !isVendored }
    var hasTests: Bool { !internalTestFiles.isEmpty || !externalTestFiles.isEmpty }
    var externalTestImportPath: String { importPath + "_test" }
}

/// The user's packages, in an order that can be compiled front to back.
///
/// The graph is small by construction — this is a learning app, not a monorepo
/// — so the ordering is a plain depth-first walk rather than anything clever,
/// and a cycle is reported instead of being broken arbitrarily.
struct GoPackageGraph {
    enum GraphError: Error, Equatable {
        case noGoFiles
        case conflictingPackageNames(directory: String, names: [String])
        case importCycle(path: [String])
        case unresolvedImport(String, importedBy: String)
    }

    let modulePath: String
    /// Dependencies first.
    let packages: [GoPackage]

    var mainPackage: GoPackage? {
        packages.first(where: \.isMain)
    }

    func package(withImportPath path: String) -> GoPackage? {
        packages.first { $0.importPath == path }
    }

    static func build(
        files: [String: String],
        modulePath: String,
        standardLibrary: some Collection<String>
    ) throws -> GoPackageGraph {
        let grouped = try group(files: files, modulePath: modulePath)
        guard !grouped.isEmpty else { throw GraphError.noGoFiles }

        let byPath = Dictionary(uniqueKeysWithValues: grouped.map { ($0.importPath, $0) })
        let known = Set(standardLibrary)

        for package in grouped {
            for imported in package.imports.union(package.testImports) {
                let isLocal = byPath[imported] != nil
                let isStandard = known.contains(imported)
                guard isLocal || isStandard else {
                    throw GraphError.unresolvedImport(imported, importedBy: package.importPath)
                }
            }
        }

        return GoPackageGraph(modulePath: modulePath, packages: try ordered(grouped, byPath: byPath))
    }

    // MARK: - Grouping

    private static func group(files: [String: String], modulePath: String) throws -> [GoPackage] {
        var byDirectory: [String: [String]] = [:]
        for path in files.keys.sorted() where path.hasSuffix(".go") {
            byDirectory[directory(of: path), default: []].append(path)
        }

        return try byDirectory.keys.sorted().compactMap { directory -> GoPackage? in
            let paths = byDirectory[directory] ?? []
            let headers = paths.reduce(into: [String: GoSourceHeader]()) { result, path in
                result[path] = GoSourceHeader.parse(files[path] ?? "")
            }

            let production = paths.filter { !$0.hasSuffix("_test.go") }
            let tests = paths.filter { $0.hasSuffix("_test.go") }
            let external = tests.filter { headers[$0]?.isExternalTestPackage == true }
            let internalTests = tests.filter { headers[$0]?.isExternalTestPackage != true }

            // A directory holding only external tests has no package to build.
            let naming = production.isEmpty ? internalTests : production
            guard let name = try packageName(of: naming, headers: headers, directory: directory) else {
                return nil
            }

            return GoPackage(
                importPath: importPath(forDirectory: directory, modulePath: modulePath),
                directory: directory,
                name: name,
                isVendored: directory.hasPrefix(GoVendorWriter.vendorDirectory + "/"),
                goFiles: production,
                internalTestFiles: internalTests,
                externalTestFiles: external,
                imports: imports(of: production, headers: headers),
                testImports: imports(of: tests, headers: headers)
            )
        }
    }

    private static func packageName(
        of paths: [String],
        headers: [String: GoSourceHeader],
        directory: String
    ) throws -> String? {
        let names = Set(paths.compactMap { headers[$0]?.packageName }.filter { !$0.isEmpty })
        guard let name = names.first else { return nil }
        guard names.count == 1 else {
            throw GraphError.conflictingPackageNames(directory: directory, names: names.sorted())
        }
        return name
    }

    private static func imports(of paths: [String], headers: [String: GoSourceHeader]) -> Set<String> {
        paths.reduce(into: Set<String>()) { result, path in
            result.formUnion(headers[path]?.imports ?? [])
        }
    }

    // MARK: - Ordering

    private static func ordered(
        _ packages: [GoPackage],
        byPath: [String: GoPackage]
    ) throws -> [GoPackage] {
        var result: [GoPackage] = []
        var settled: Set<String> = []
        var onStack: [String] = []

        func visit(_ package: GoPackage) throws {
            if settled.contains(package.importPath) { return }
            if let cycleStart = onStack.firstIndex(of: package.importPath) {
                throw GraphError.importCycle(path: Array(onStack[cycleStart...]) + [package.importPath])
            }
            onStack.append(package.importPath)
            // Test imports are deliberately excluded: a package under test may
            // be imported by its own external test package, and treating that
            // as a build edge would report a cycle Go does not have.
            for imported in package.imports.sorted() {
                if let dependency = byPath[imported] { try visit(dependency) }
            }
            onStack.removeLast()
            settled.insert(package.importPath)
            result.append(package)
        }

        for package in packages { try visit(package) }
        return result
    }

    // MARK: - Paths

    static func directory(of path: String) -> String {
        guard let index = path.lastIndex(of: "/") else { return "" }
        return String(path[path.startIndex..<index])
    }

    /// A vendored package keeps the import path it was published under, not
    /// one derived from this module. `vendor/github.com/google/uuid` is
    /// imported as `github.com/google/uuid`, which is the whole point of
    /// vendoring: the code that imports it does not change.
    static func importPath(forDirectory directory: String, modulePath: String) -> String {
        let vendorPrefix = GoVendorWriter.vendorDirectory + "/"
        if directory.hasPrefix(vendorPrefix) {
            return String(directory.dropFirst(vendorPrefix.count))
        }
        return directory.isEmpty ? modulePath : "\(modulePath)/\(directory)"
    }
}
