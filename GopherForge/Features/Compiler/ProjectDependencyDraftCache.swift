import CryptoKit
import Foundation

/// Verified dependency snapshots are recoverable staging data, never autosaves.
/// A draft can be resumed only for the same project and exact original files.
actor ProjectDependencyDraftCache {
    static let shared = ProjectDependencyDraftCache()
    private let root: URL
    private let maximumBytes: Int
    private struct Draft: Codable {
        let schemaVersion: Int
        let owner: UUID
        let baseDigest: String
        let files: [String: String]
    }

    init(root: URL? = nil, maximumBytes: Int = 64 * 1024 * 1024) {
        self.root = root ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "GopherForge/PreparedDependencies", directoryHint: .isDirectory)
        self.maximumBytes = maximumBytes
    }

    func load(owner: UUID, base: [String: String]) -> [String: String]? {
        let url = file(owner)
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumBytes, let data = try? Data(contentsOf: url),
              let draft = try? JSONDecoder().decode(Draft.self, from: data),
              draft.schemaVersion == 1, draft.owner == owner,
              draft.baseDigest == digest(base) else { return nil }
        return draft.files
    }

    func save(owner: UUID, base: [String: String], files: [String: String]) {
        guard files.reduce(0, { $0 + $1.key.utf8.count + $1.value.utf8.count }) < maximumBytes,
              let data = try? JSONEncoder().encode(Draft(
                schemaVersion: 1, owner: owner, baseDigest: digest(base), files: files
              )), data.count <= maximumBytes else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: file(owner), options: .atomic)
            let urls = try FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.pathExtension == "json" }.sorted {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                    > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }
            for url in urls.dropFirst(4) { try? FileManager.default.removeItem(at: url) }
        } catch {
            // Cache pressure must not fail or overwrite a user's source save.
        }
    }

    private func file(_ owner: UUID) -> URL { root.appending(path: owner.uuidString + ".json") }

    private func digest(_ files: [String: String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(files)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
