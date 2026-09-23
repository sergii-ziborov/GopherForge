import CryptoKit
import Foundation

/// Materialises an in-memory project into the job's working directory.
///
/// Every relative path is validated before it is joined: a project file that
/// escaped the working directory would let a build read or write outside the
/// sandbox, so a rejected path fails the job rather than being sanitised into
/// something that merely looks safe.
struct GoWorkspaceStager {
    enum StagingError: Error, Equatable {
        case invalidPath(String)
    }

    struct Layout {
        let jobRoot: URL
        let work: URL
        let temp: URL
        let cache: URL
        let sandbox: URL

        /// Translates a path the plan expressed in guest terms into the host
        /// file the app should write or read.
        ///
        /// Only the directories actually preopened for the job resolve, and
        /// each component is checked the same way a staged project path is, so
        /// a plan cannot name a host file outside the sandbox even if a project
        /// managed to smuggle a traversal into an import path.
        func hostURL(forGuestPath guestPath: String) -> URL? {
            let roots = [
                "/work": work,
                "/tmp": temp,
                "/cache": cache,
            ]
            for (prefix, root) in roots where guestPath == prefix || guestPath.hasPrefix(prefix + "/") {
                let relative = String(guestPath.dropFirst(prefix.count + 1))
                if relative.isEmpty { return root }
                return GoWorkspaceStager.resolve(relativePath: relative, under: root)
            }
            return nil
        }
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// `persistentRoot` keeps `/work`, `/tmp` and `/cache` across jobs for the
    /// same project. The expensive part of a second Run was never compile.wasm
    /// alone — it was rewriting every vendored file and every cached `.a`
    /// into a fresh directory first.
    func createLayout(named jobName: String, persistentRoot: URL? = nil) throws -> Layout {
        let jobRoot = fileManager.temporaryDirectory
            .appendingPathComponent("GopherForgeCompiler", isDirectory: true)
            .appendingPathComponent(jobName, isDirectory: true)
        let work = persistentRoot?.appendingPathComponent("work", isDirectory: true)
            ?? jobRoot.appendingPathComponent("work", isDirectory: true)
        let temp = persistentRoot?.appendingPathComponent("tmp", isDirectory: true)
            ?? jobRoot.appendingPathComponent("tmp", isDirectory: true)
        let cache = persistentRoot?.appendingPathComponent("cache", isDirectory: true)
            ?? jobRoot.appendingPathComponent("cache", isDirectory: true)
        let layout = Layout(
            jobRoot: jobRoot,
            work: work,
            temp: temp,
            cache: cache,
            sandbox: jobRoot.appendingPathComponent("sandbox", isDirectory: true)
        )
        for directory in [layout.work, layout.temp, layout.cache, layout.sandbox] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return layout
    }

    /// Writes only files whose contents hash changed, and drops leftovers.
    ///
    /// Comparing hashes against a sidecar avoids reading every vendored file
    /// back off disk on each keystroke. A fresh job directory used to rewrite
    /// the whole tree on every Run; after a real module is installed that is
    /// most of the I/O, and none of it is new.
    func stage(files: [String: String], into work: URL) throws {
        let manifestURL = work.appendingPathComponent(Self.manifestName)
        let previous = Self.readManifest(at: manifestURL)
        var next: [String: String] = [:]
        var expected: Set<String> = []
        for (relativePath, contents) in files.sorted(by: { $0.key < $1.key }) {
            guard let fileURL = Self.resolve(relativePath: relativePath, under: work) else {
                throw StagingError.invalidPath(relativePath)
            }
            expected.insert(relativePath)
            let digest = Self.digest(contents)
            next[relativePath] = digest
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if previous[relativePath] == digest,
               fileManager.fileExists(atPath: fileURL.path) {
                continue
            }
            try Data(contents.utf8).write(to: fileURL)
        }
        try prune(work: work, keeping: expected)
        try Self.writeManifest(next, to: manifestURL)
    }

    func remove(_ layout: Layout) {
        let jobPath = layout.jobRoot.standardizedFileURL.path
        func isInsideJob(_ url: URL) -> Bool {
            let path = url.standardizedFileURL.path
            return path == jobPath || path.hasPrefix(jobPath + "/")
        }
        if isInsideJob(layout.work), isInsideJob(layout.temp), isInsideJob(layout.cache) {
            try? fileManager.removeItem(at: layout.jobRoot)
            return
        }
        if isInsideJob(layout.sandbox) {
            try? fileManager.removeItem(at: layout.sandbox)
        }
        try? fileManager.removeItem(at: layout.jobRoot)
    }

    static func persistentRootURL(for reuseKey: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches
            .appendingPathComponent("GopherForgeWork", isDirectory: true)
            .appendingPathComponent(reuseKey, isDirectory: true)
    }

    private func prune(work: URL, keeping expected: Set<String>) throws {
        guard let enumerator = fileManager.enumerator(
            at: work,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return
        }
        let root = work.standardizedFileURL.path
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(root + "/") else { continue }
            let relative = String(path.dropFirst(root.count + 1))
            if relative == Self.manifestName { continue }
            if !expected.contains(relative) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    static func resolve(relativePath: String, under root: URL) -> URL? {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
              !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            return nil
        }
        return components.reduce(root) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }

    static func digest(_ contents: String) -> String {
        SHA256.hash(data: Data(contents.utf8))
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static let manifestName = ".gopherforge-stage"

    private static func readManifest(at url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private static func writeManifest(_ hashes: [String: String], to url: URL) throws {
        let data = try JSONEncoder().encode(hashes)
        try data.write(to: url)
    }
}
