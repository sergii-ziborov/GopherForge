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

    private let toolchainTag: String
    private let fileManager: FileManager
    private let lock = NSLock()
    private var parsedModules: [String: Module] = [:]
    private var acceptedBuildKeys: Set<String> = []

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
        lock.withLock { _ = acceptedBuildKeys.insert(key) }
    }

    func module(for key: String) -> Module? {
        if let module = lock.withLock({ parsedModules[key] }) { return module }
        guard let url = artifactURL(for: key),
              fileManager.fileExists(atPath: url.path)
        else {
            return nil
        }
        do {
            let module = try parseWasm(bytes: [UInt8](Data(contentsOf: url)))
            lock.withLock { parsedModules[key] = module }
            return module
        } catch {
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    func store(programData: Data, module: Module, for key: String) {
        lock.withLock { parsedModules[key] = module }
        guard let directory = cacheDirectory, let url = artifactURL(for: key) else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try programData.write(to: url, options: .atomic)
        } catch {
            // Deliberately ignored: the program already built and ran.
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
