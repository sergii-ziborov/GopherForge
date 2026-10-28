import Foundation

/// Reads a Go project from a folder the user picked in Files.
///
/// Everything here is bounded on purpose. A picked folder is arbitrary user
/// data: it can be enormous, contain binaries, or point at a whole home
/// directory, and none of those should be able to hang the app or fill its
/// container.
struct LocalProjectLoader {
    struct Limits {
        var maximumFileCount = 2_000
        var maximumFileBytes = 512 * 1024
        var maximumTotalBytes = 24 * 1024 * 1024

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
        var report = ProjectImportReport()
        if root != directory { report.scopeNote = "Imported module subfolder: \(root.lastPathComponent). Other checkout folders were not imported." }
        let files = try readFiles(under: root, report: &report)

        guard files.keys.contains(where: { $0.hasSuffix(".go") }) else {
            throw LoadError.noGoFiles
        }

        return GopherForgeProject(
            name: root.lastPathComponent,
            files: files,
            entryFile: entryFile(in: files),
            provenance: GopherForgeProject.Provenance(
                source: .files, owner: nil, repository: nil, reference: nil,
                commit: nil, importedAt: Date(), importReport: report
            )
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
            guard (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
                  fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  fileManager.fileExists(atPath: child.appending(path: "go.mod").path)
            else {
                continue
            }
            return child
        }
        return nil
    }

    private func readFiles(under root: URL, report: inout ProjectImportReport) throws -> [String: String] {
        var entries: [String: Data] = [:]
        var totalBytes = 0
        var visited = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        var enumerationError: Error?
        let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: []) { _, error in
            enumerationError = error
            return false
        }
        while let url = enumerator?.nextObject() as? URL {
            visited += 1
            guard visited <= 50_000 else { throw LoadError.tooManyFiles(50_000) }
            let path = relative(url, to: root)
            let values = try url.resourceValues(forKeys: keys)
            if values.isSymbolicLink == true {
                enumerator?.skipDescendants()
                report.skip(path, "Symbolic link (not followed)")
                continue
            }
            if values.isDirectory == true {
                if ProjectImportFilter.excludedDirectories.contains(url.lastPathComponent) {
                    enumerator?.skipDescendants()
                    report.skip(path + "/", "Metadata or generated dependency directory")
                }
                continue
            }
            guard values.isRegularFile == true else { report.skip(path, "Non-regular file"); continue }
            if let reason = ProjectImportFilter.reasonForPath(path) { report.skip(path, reason); continue }
            guard (values.fileSize ?? 0) <= limits.maximumFileBytes else { report.skip(path, "File byte limit"); continue }
            let data = try Data(contentsOf: url)
            guard data.count <= limits.maximumFileBytes else { report.skip(path, "File byte limit"); continue }
            totalBytes += data.count
            guard totalBytes <= limits.maximumTotalBytes else { throw LoadError.tooLarge }
            entries[path] = data
        }
        if let enumerationError { throw enumerationError }
        let files = ProjectImportFilter.select(entries, report: &report, maximumFiles: limits.maximumFileCount, maximumFileBytes: limits.maximumFileBytes)
        if report.reasons["Snapshot file limit"] != nil { throw LoadError.tooManyFiles(limits.maximumFileCount) }
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
