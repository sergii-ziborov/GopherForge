import Foundation
import CryptoKit
import WasmKit

/// Caches successfully built guest programs, keyed by everything that can
/// change their bytes.
///
/// The learning loop compiles the same unchanged program repeatedly, and a Go
/// build inside an interpreter is slow enough that this is the difference
/// between a usable and an unusable lesson. A cache miss is always safe; a
/// cache write failure never turns a successful build into a failure.
final class GoArtifactCache: @unchecked Sendable {
    private static let schemaVersion = "wasip1-1"

    /// How many parsed modules are held in memory at once.
    ///
    /// Every keystroke that reaches a build makes a new key, so this map used
    /// to have no ceiling at all: editing and running is the ordinary way to
    /// use the app, and each unique source produced another parsed module that
    /// was never released. Small on purpose — the value here is skipping the
    /// re-parse of what you just ran, and nobody goes back to the program they
    /// had eight edits ago.
    private static let parsedModuleCapacity = 8

    /// Verdicts are cheap to hold but not free, and they grow the same way.
    private static let acceptedBuildCapacity = 512

    /// What the stored programs may occupy before the oldest are dropped.
    ///
    /// Provisional: a ceiling that exists is the point, and the right number
    /// comes from the device gate rather than from here. iOS may purge Caches
    /// under pressure, but that is the system's policy and not this app's.
    private static let diskBudgetBytes: Int64 = 128 * 1024 * 1024

    private let toolchainTag: String
    private let fileManager: FileManager
    private let lock = NSLock()
    private var parsedModules: [String: Module] = [:]
    /// Least-recently-used last. Kept beside the map rather than inside a
    /// general LRU type because eight entries do not need one.
    private var parsedModuleOrder: [String] = []
    private var acceptedBuildKeys: Set<String> = []
    private var acceptedBuildOrder: [String] = []

    init(toolchainTag: String, fileManager: FileManager = .default) {
        self.toolchainTag = toolchainTag
        self.fileManager = fileManager
    }

    func key(phase: CompilationResult.Phase, files: [String: String]) -> String {
        var hasher = SHA256()
        for value in [toolchainTag, Self.schemaVersion, phase.rawValue] {
            hasher.update(data: Data(value.utf8))
            hasher.update(data: Data([0]))
        }
        for (path, contents) in files.sorted(by: { $0.key < $1.key }) {
            hasher.update(data: Data(path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data(contents.utf8))
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// A non-`run` phase has no artifact, only a verdict, so success is
    /// remembered as a key rather than as bytes.
    func hasAcceptedBuild(for key: String) -> Bool {
        lock.withLock { acceptedBuildKeys.contains(key) }
    }

    func rememberAcceptedBuild(for key: String) {
        lock.withLock {
            guard acceptedBuildKeys.insert(key).inserted else { return }
            acceptedBuildOrder.append(key)
            while acceptedBuildOrder.count > Self.acceptedBuildCapacity {
                acceptedBuildKeys.remove(acceptedBuildOrder.removeFirst())
            }
        }
    }

    func module(for key: String) -> Module? {
        if let module = lock.withLock({ touchParsed(key) }) { return module }
        guard let url = artifactURL(for: key),
              fileManager.fileExists(atPath: url.path)
        else {
            return nil
        }
        do {
            let module = try parseWasm(bytes: [UInt8](Data(contentsOf: url)))
            lock.withLock { rememberParsed(module, for: key) }
            return module
        } catch {
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    func store(programData: Data, module: Module, for key: String) {
        lock.withLock { rememberParsed(module, for: key) }
        guard let directory = cacheDirectory, let url = artifactURL(for: key) else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try programData.write(to: url, options: .atomic)
            trimToDiskBudget()
        } catch {
            // Deliberately ignored: the program already built and ran.
        }
    }

    /// Returns a held module and moves it to the front. Call under the lock.
    private func touchParsed(_ key: String) -> Module? {
        guard let module = parsedModules[key] else { return nil }
        if let index = parsedModuleOrder.firstIndex(of: key) {
            parsedModuleOrder.remove(at: index)
        }
        parsedModuleOrder.append(key)
        return module
    }

    /// Holds a module, dropping the least recently used. Call under the lock.
    private func rememberParsed(_ module: Module, for key: String) {
        parsedModules[key] = module
        if let index = parsedModuleOrder.firstIndex(of: key) {
            parsedModuleOrder.remove(at: index)
        }
        parsedModuleOrder.append(key)
        while parsedModuleOrder.count > Self.parsedModuleCapacity {
            parsedModules.removeValue(forKey: parsedModuleOrder.removeFirst())
        }
    }

    /// Deletes the least recently modified artifacts until the directory fits.
    ///
    /// By modification date because that is what the filesystem records for
    /// free; a build that is reused is rewritten, so it stays young.
    private func trimToDiskBudget() {
        guard let directory = cacheDirectory,
              let entries = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
              )
        else {
            return
        }

        var sized = entries.compactMap { url -> (url: URL, size: Int64, date: Date)? in
            guard let values = try? url.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            ) else { return nil }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }

        var total = sized.reduce(Int64(0)) { $0 + $1.size }
        guard total > Self.diskBudgetBytes else { return }

        sized.sort { $0.date < $1.date }
        for entry in sized where total > Self.diskBudgetBytes {
            guard (try? fileManager.removeItem(at: entry.url)) != nil else { continue }
            total -= entry.size
        }
    }

    /// Drops everything remembered, in memory and on disk.
    ///
    /// Two callers need this and both are real. A user reclaiming storage is
    /// one. The other is the compiler gate: a cached artifact makes a build
    /// that never happened look exactly like one that did, so a gate that can
    /// pass on a remembered program is not a gate at all.
    func clear() {
        lock.withLock {
            parsedModules.removeAll()
            parsedModuleOrder.removeAll()
            acceptedBuildKeys.removeAll()
            acceptedBuildOrder.removeAll()
        }
        guard let directory = cacheDirectory else { return }
        try? fileManager.removeItem(at: directory)
    }

    /// How many parsed modules are held. The bound is the point of the cache's
    /// eviction, so it is worth being able to assert on it.
    var heldModuleCount: Int {
        lock.withLock { parsedModules.count }
    }

    /// What the stored artifacts occupy, so the user can be told before being
    /// asked whether to remove them.
    var storedByteCount: Int64 {
        guard let directory = cacheDirectory,
              let entries = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.fileSizeKey]
              )
        else {
            return 0
        }
        return entries.reduce(0) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GopherForgeCompiler", isDirectory: true)
            .appendingPathComponent(toolchainTag, isDirectory: true)
            .appendingPathComponent(Self.schemaVersion, isDirectory: true)
    }

    private func artifactURL(for key: String) -> URL? {
        cacheDirectory?.appendingPathComponent("\(key).wasm")
    }
}
