import CryptoKit
import Foundation

/// A snapshot inventory, not a claim that the complete Git worktree was kept.
struct ProjectImportReport: Codable, Equatable, Sendable {
    struct Omission: Codable, Equatable, Sendable {
        let path: String
        let reason: String
    }
    var schemaVersion = 1
    var retainedPaths: [String] = []
    var omissions: [Omission] = []
    var omissionCount = 0
    var reasons: [String: Int] = [:]
    var archiveSHA256: String?
    var scopeNote: String?
    var isPartial: Bool { omissionCount > 0 || scopeNote != nil }

    mutating func skip(_ path: String, _ reason: String) {
        omissionCount += 1
        reasons[reason, default: 0] += 1
        if omissions.count < 2_000 {
            omissions.append(Omission(path: String(path.prefix(1_024)), reason: reason))
        }
    }
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// A bounded text snapshot. Opaque assets remain in the original location;
/// every omission is inventoried until a full-worktree store is available.
enum ProjectImportFilter {
    static let extensions: Set<String> = [
        "go", "mod", "sum", "work", "md", "txt", "json", "yaml", "yml", "toml", "gitignore",
        "html", "htm", "js", "mjs", "cjs", "jsx", "ts", "tsx", "css", "scss", "svg", "csv",
        "xml", "sql", "sh", "bash", "zsh", "proto", "graphql", "gql", "env", "ini", "cfg", "conf",
    ]
    static let names: Set<String> = [
        "LICENSE", "NOTICE", "AUTHORS", "Makefile", "Dockerfile", ".dockerignore", ".gitignore",
        GopherForgeProject.folderMarker,
    ]
    static let excludedDirectories: Set<String> = [".git", "node_modules", ".next", ".gopherforge-backups"]

    static func reasonForPath(_ path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard !path.hasPrefix("/"), !parts.isEmpty,
              !parts.contains(".."), !parts.contains("."), !path.contains("\\") else { return "Unsafe path" }
        if parts.dropLast().contains(where: { excludedDirectories.contains($0) }) { return "Metadata or generated dependency directory" }
        let name = parts.last ?? path
        if names.contains(name) { return nil }
        let ext = (name as NSString).pathExtension.lowercased()
        return extensions.contains(ext) ? nil : "Unsupported asset type"
    }

    static func select(
        _ entries: [String: Data], report: inout ProjectImportReport,
        maximumFiles: Int = 2_000, maximumFileBytes: Int = 512 * 1_024
    ) -> [String: String] {
        var files: [String: String] = [:]
        // Own build source first, then vendor, then the rest. No unreported truncation.
        func priority(_ path: String) -> Int {
            if SourceFileLimit.isBuildEssential(path) { return path.hasPrefix("vendor/") ? 1 : 0 }
            return 2
        }
        let paths = entries.keys.sorted { priority($0) == priority($1) ? $0 < $1 : priority($0) < priority($1) }
        for path in paths {
            if let reason = reasonForPath(path) { report.skip(path, reason); continue }
            guard let data = entries[path] else { continue }
            guard data.count <= maximumFileBytes else { report.skip(path, "File byte limit"); continue }
            guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
                report.skip(path, "Not UTF-8 text"); continue
            }
            guard !SourceFileLimit.exceedsImportLimit(text, path: path) else { report.skip(path, "Editor line limit"); continue }
            guard files.count < maximumFiles else { report.skip(path, "Snapshot file limit"); continue }
            files[path] = text
        }
        report.retainedPaths = files.keys.sorted()
        return files
    }
}
