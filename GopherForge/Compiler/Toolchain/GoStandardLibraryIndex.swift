import Foundation

/// Which standard-library packages the bundled toolchain can actually link.
///
/// The index is read from what was staged rather than from a list checked into
/// the app, so it can never claim a package the artifact does not carry. An
/// import the index does not know is refused before a single tool runs, which
/// turns a linker error nobody can read into a sentence about the import.
struct GoStandardLibraryIndex: Sendable, Equatable {
    let importPaths: Set<String>

    var isEmpty: Bool { importPaths.isEmpty }

    static let empty = GoStandardLibraryIndex(importPaths: [])

    /// Packages the compiler provides itself, with no archive anywhere.
    ///
    /// `unsafe` is not a library — it is a name the compiler understands, and
    /// there is no `unsafe.a` to point an import configuration at. It has to be
    /// resolvable all the same, or any dependency that touches it (which is
    /// most reflection-based ones) is refused before it is tried.
    static let compilerProvided: Set<String> = ["unsafe"]

    /// Everything an import may legally name: what was staged, plus what the
    /// compiler supplies without a file.
    var resolvableImportPaths: Set<String> {
        importPaths.union(Self.compilerProvided)
    }

    /// Walks the staged export data. Every `<path>.a` under the package root
    /// is one import path, with the root prefix and the extension removed.
    static func load(
        packageRoot: URL,
        fileManager: FileManager = .default
    ) -> GoStandardLibraryIndex {
        guard let enumerator = fileManager.enumerator(
            at: packageRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .empty
        }

        let rootComponents = packageRoot.standardizedFileURL.pathComponents
        var paths: Set<String> = []

        for case let url as URL in enumerator where url.pathExtension == "a" {
            let components = url.standardizedFileURL.deletingPathExtension().pathComponents
            guard components.count > rootComponents.count,
                  Array(components.prefix(rootComponents.count)) == rootComponents
            else {
                continue
            }
            paths.insert(components.dropFirst(rootComponents.count).joined(separator: "/"))
        }

        return GoStandardLibraryIndex(importPaths: paths)
    }
}
