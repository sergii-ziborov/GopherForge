import Foundation

/// Names for exported archives, and the project that comes back out of one.
///
/// Small and separate because it is the part everyone sees: the file name in a
/// share sheet, the directory that appears when someone runs `tar xzf`, and
/// the project's name when the archive is opened again.
enum ProjectArchiveNaming {
    /// A file-system-safe version of the project's name, never empty.
    static func rootDirectory(for projectName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let cleaned = String(
            projectName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        )
        .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return cleaned.isEmpty ? "gopherforge-project" : cleaned.lowercased()
    }

    static func archiveName(for projectName: String) -> String {
        "\(rootDirectory(for: projectName)).tar.gz"
    }

    /// `worker-pool.tar.gz` opens as `worker-pool`.
    static func projectName(fromArchive fileName: String) -> String {
        var name = fileName
        for suffix in [".tar.gz", ".tgz", ".gz"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name.isEmpty ? "Imported project" : name
    }

    /// The file the editor should open first: the module's own `main.go` if it
    /// has one, then any main, then whatever comes first alphabetically.
    static func entryFile(in files: [String: String]) -> String {
        let paths = files.keys.sorted()
        if paths.contains("main.go") { return "main.go" }
        if let main = paths.first(where: { $0.hasSuffix("/main.go") }) { return main }
        if let anyGo = paths.first(where: { $0.hasSuffix(".go") }) { return anyGo }
        return paths.first ?? "main.go"
    }
}
