import Foundation

/// Reads a Go project from a folder the user picked in Files.
///
/// Everything here is bounded on purpose. A picked folder is arbitrary user
/// data: it can be enormous, contain binaries, or point at a whole home
/// directory, and none of those should be able to hang the app or fill its
/// container.
struct LocalProjectLoader {
    struct Limits {
        var maximumFileCount = 400
        var maximumFileBytes = 512 * 1024
        var maximumTotalBytes = 8 * 1024 * 1024

        static let standard = Limits()
    }

    enum LoadError: LocalizedError, Equatable {
        case notADirectory
        case noGoFiles
        case tooManyFiles(Int)
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .notADirectory: "Pick a folder, not a single file."
            case .noGoFiles: "That folder has no Go files."
            case .tooManyFiles(let limit): "That folder has more than \(limit) files."
            case .tooLarge: "That folder is larger than GopherForge opens."
            }
        }
    }

    /// Extensions worth opening in a Go project. Anything else is skipped
    /// rather than loaded as garbage text.
    private static let readableExtensions: Set<String> = [
        "go", "mod", "sum", "md", "txt", "json", "yaml", "yml", "toml", "work",
    ]

    private let fileManager: FileManager
    private let limits: Limits

    init(fileManager: FileManager = .default, limits: Limits = .standard) {
        self.fileManager = fileManager
        self.limits = limits
    }

    func load(from directory: URL) throws -> GopherForgeProject {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw LoadError.notADirectory
        }

        // A repository often holds the module one level down. Opening the
        // module root rather than the checkout root is what makes the file
        // tree and the build agree.
        let root = moduleRoot(in: directory) ?? directory
        let files = try readFiles(under: root)

        guard files.keys.contains(where: { $0.hasSuffix(".go") }) else {
            throw LoadError.noGoFiles
        }

        return GopherForgeProject(
            name: root.lastPathComponent,
            files: files,
            entryFile: entryFile(in: files),
            provenance: .files()
        )
    }

    /// The shallowest directory containing a `go.mod`.
    private func moduleRoot(in directory: URL) -> URL? {
        if fileManager.fileExists(atPath: directory.appending(path: "go.mod").path) {
            return directory
        }
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for child in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  fileManager.fileExists(atPath: child.appending(path: "go.mod").path)
            else {
                continue
            }
            return child
        }
        return nil
    }

    private func readFiles(under root: URL) throws -> [String: String] {
        var files: [String: String] = [:]
        var totalBytes = 0

        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let url = enumerator?.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            guard Self.readableExtensions.contains(url.pathExtension.lowercased()) else { continue }

            let size = values?.fileSize ?? 0
            guard size <= limits.maximumFileBytes else { continue }

            totalBytes += size
            guard totalBytes <= limits.maximumTotalBytes else { throw LoadError.tooLarge }
            guard files.count < limits.maximumFileCount else {
                throw LoadError.tooManyFiles(limits.maximumFileCount)
            }

            guard let data = try? Data(contentsOf: url) else { continue }
            let relativePath = relative(url, to: root)
            files[relativePath] = String(decoding: data, as: UTF8.self)
        }

        return files
    }

    /// `main.go` in the module root if there is one, otherwise the first Go
    /// file, so the editor always opens on something.
    private func entryFile(in files: [String: String]) -> String {
        if files.keys.contains("main.go") { return "main.go" }
        let goFiles = files.keys.filter { $0.hasSuffix(".go") }.sorted()
        return goFiles.first(where: { !$0.hasSuffix("_test.go") }) ?? goFiles.first ?? "go.mod"
    }

    private func relative(_ url: URL, to root: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        guard urlComponents.count > rootComponents.count,
              Array(urlComponents.prefix(rootComponents.count)) == rootComponents
        else {
            return url.lastPathComponent
        }
        return urlComponents.dropFirst(rootComponents.count).joined(separator: "/")
    }
}
