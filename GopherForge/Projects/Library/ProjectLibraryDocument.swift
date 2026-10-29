import CryptoKit
import Foundation

/// All readers and writers use the coordinated URL, with the read/modify/write
/// inside one write accessor. No actor-local whole-document cache is reused.
enum ProjectLibraryDocument {
    struct State: Codable, Equatable {
        var items: [ProjectLibraryItem]
        var schemaVersion: Int? = 1
    }

    static func read(_ url: URL, requireExisting: Bool = false) throws -> State {
        guard FileManager.default.fileExists(atPath: url.path) else {
            if requireExisting { throw ProjectLibrary.StorageError.missingDocument }
            return State(items: [])
        }
        var coordinationError: NSError?
        var result: Result<State, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                var state = try decode(coordinated)
                for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: coordinated) ?? [] {
                    merge(try decode(version.url), into: &state)
                }
                return state
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ProjectLibrary.StorageError.verificationFailed }
        return try result.get()
    }

    static func modify<T>(_ url: URL, requireExisting: Bool = false, _ update: (inout State) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinated in
            result = Result {
                let exists = FileManager.default.fileExists(atPath: coordinated.path)
                if requireExisting && !exists { throw ProjectLibrary.StorageError.missingDocument }
                let before = exists ? try Data(contentsOf: coordinated) : nil
                var state = exists ? try decode(coordinated) : State(items: [])
                let previous = state
                let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: coordinated) ?? []
                for version in conflicts {
                    let other = try decode(version.url) // Fail closed on corrupt/future versions.
                    merge(other, into: &state)
                    try backup(try Data(contentsOf: version.url), beside: coordinated)
                }
                let value = try update(&state)
                if state != previous || !conflicts.isEmpty {
                    state.items.sort { $0.lastOpenedAt > $1.lastOpenedAt }
                    if let before { try backup(before, beside: coordinated) }
                    let encoded = try JSONEncoder.gopherForge.encode(state)
                    if before == nil { try backup(encoded, beside: coordinated) }
                    try encoded.write(to: coordinated, options: .atomic)
                    guard try Data(contentsOf: coordinated) == encoded else { throw ProjectLibrary.StorageError.verificationFailed }
                    // Every conflicting source is now present in the main document.
                    for version in conflicts { version.isResolved = true; try? version.remove() }
                    pruneBackups(beside: coordinated)
                }
                return value
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ProjectLibrary.StorageError.verificationFailed }
        return try result.get()
    }

    private static func decode(_ url: URL) throws -> State {
        let state = try JSONDecoder.gopherForge.decode(State.self, from: Data(contentsOf: url))
        guard (state.schemaVersion ?? 1) == 1 else { throw ProjectLibrary.StorageError.unsupportedSchema }
        guard Set(state.items.map(\.id)).count == state.items.count else { throw ProjectLibrary.StorageError.verificationFailed }
        return state
    }

    /// Source identity is byte-based, independent of Swift's Unicode equivalence.
    static func sourceDigest(_ files: [String: String]) -> String {
        var hash = SHA256()
        for path in files.keys.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            for value in [path, files[path]!] {
                var length = UInt64(value.utf8.count).bigEndian
                withUnsafeBytes(of: &length) { hash.update(data: Data($0)) }
                hash.update(data: Data(value.utf8))
            }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func merge(_ other: State, into state: inout State) {
        for item in other.items {
            let known = state.items.first { $0.id == item.id }
            if known?.project == item.project,
               known.map({ sourceDigest($0.project.files) }) == sourceDigest(item.project.files) { continue }
            var salt = 0
            while true {
                let copy = recoveryCopy(item, reason: "iCloud recovery", stable: true, salt: salt)
                guard let existing = state.items.first(where: { $0.id == copy.id }) else { state.items.append(copy); break }
                if existing.project == copy.project,
                   sourceDigest(existing.project.files) == sourceDigest(copy.project.files) { break }
                salt += 1 // Even an externally constructed UUID collision cannot discard source.
            }
        }
    }

    static func recoveryCopy(_ item: ProjectLibraryItem, reason: String, stable: Bool = false, salt: Int = 0) -> ProjectLibraryItem {
        let encoder = JSONEncoder.gopherForge
        encoder.outputFormatting = .sortedKeys
        var bytes = (try? encoder.encode(item)) ?? Data()
        if salt > 0 { bytes.append(Data("/\(salt)".utf8)) }
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let uuid = "\(hash.prefix(8))-\(hash.dropFirst(8).prefix(4))-\(hash.dropFirst(12).prefix(4))-\(hash.dropFirst(16).prefix(4))-\(hash.dropFirst(20).prefix(12))"
        return ProjectLibraryItem(
            id: stable ? UUID(uuidString: uuid)! : UUID(),
            project: item.project.renamed(to: "\(item.project.name) (\(reason))"),
            lastOpenedAt: stable ? item.lastOpenedAt : Date(), sourceRevision: item.sourceRevision,
            folder: item.folder, tags: item.tags, isFavorite: false,
            summary: "A conflicting version was kept separately. Compare both projects before deleting either."
        )
    }

    private static func backupFolder(_ url: URL) -> URL {
        url.deletingLastPathComponent().appending(path: ".gopherforge-backups/" + url.lastPathComponent, directoryHint: .isDirectory)
    }

    static func hasRecoveryFiles(beside url: URL) -> Bool {
        ((try? FileManager.default.contentsOfDirectory(atPath: backupFolder(url).path)) ?? [])
            .contains { $0.hasSuffix(".json") }
    }

    private static func backup(_ data: Data, beside url: URL) throws {
        let folder = backupFolder(url)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: UUID().uuidString + ".json"), options: .atomic)
    }

    private static func pruneBackups(beside url: URL) {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: backupFolder(url), includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )) ?? []
        let ordered = urls.sorted {
            ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }
        var bytes = 0
        for (index, item) in ordered.enumerated() {
            bytes += (try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if index > 0, index >= 8 || bytes > 64 * 1024 * 1024 { try? FileManager.default.removeItem(at: item) }
        }
    }
}
