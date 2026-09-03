import Foundation

/// Keeps compiled package archives between builds.
///
/// Editing one file should recompile one package. Without this every build
/// recompiles the whole graph, which is tolerable on a laptop and not on a
/// phone, where installing one dependency can add a dozen packages that will
/// never change again.
///
/// Safety comes from the key rather than from bookkeeping: a step's fingerprint
/// covers the toolchain, the language version, the package's sources and — by
/// recursion — everything it imports. If anything that decides the output
/// changes, so does the key, and the old bytes are simply never asked for.
final class GoStepArtifactCache: @unchecked Sendable {
    private let directory: URL?
    private let fileManager: FileManager
    private let lock = NSLock()
    /// Bounded rather than unbounded: a phone is not the place for a build
    /// cache that grows forever, and an archive is cheap to produce again.
    private let maximumEntries = 400

    /// And bounded in bytes, which is the limit that actually matters.
    ///
    /// Four hundred entries says nothing about size: a package archive for a
    /// small package is a few kilobytes and for a large one several megabytes,
    /// so the same count can mean anything between a few megabytes and most of
    /// a gigabyte. A count alone was not a ceiling on storage, only on
    /// bookkeeping. Provisional in the same way the program cache's budget is:
    /// the number to keep comes from the device gate.
    ///
    /// Injectable only so a test can reach it: proving the trim with the real
    /// ceiling would mean writing 192 MiB, and a test that writes less than
    /// the budget proves nothing at all.
    private let maximumBytes: Int

    init(
        toolchainTag: String,
        fileManager: FileManager = .default,
        maximumBytes: Int = 192 * 1024 * 1024
    ) {
        self.fileManager = fileManager
        self.maximumBytes = maximumBytes
        directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GopherForgeSteps", isDirectory: true)
            .appendingPathComponent(toolchainTag, isDirectory: true)
    }

    func archive(for key: String) -> Data? {
        guard let url = url(for: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// A write failure is ignored on purpose: the step already ran and its
    /// output is already in the sandbox, so a cache that cannot be written must
    /// never turn a successful build into a failed one.
    func store(_ data: Data, for key: String) {
        guard let directory, let url = url(for: key) else { return }
        lock.withLock {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        trimIfNeeded()
    }

    func clear() {
        guard let directory else { return }
        lock.withLock { try? fileManager.removeItem(at: directory) }
    }

    var storedByteCount: Int64 {
        entries().reduce(0) { $0 + Int64($1.size) }
    }

    // MARK: - Storage

    private func url(for key: String) -> URL? {
        // Keys are hex, so they are safe as file names by construction; the
        // guard is here so a future key format cannot quietly become a path.
        guard key.count == 64, key.allSatisfy({ $0.isHexDigit }) else { return nil }
        return directory?.appendingPathComponent("\(key).a")
    }

    private struct Entry {
        let url: URL
        let size: Int
        let accessed: Date
    }

    private func entries() -> [Entry] {
        guard let directory,
              let urls = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
              )
        else {
            return []
        }
        return urls.compactMap { url in
            let values = try? url.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            return Entry(
                url: url,
                size: values?.fileSize ?? 0,
                accessed: values?.contentModificationDate ?? .distantPast
            )
        }
    }

    /// Oldest first, which for build artifacts is a good enough proxy for
    /// least useful.
    ///
    /// Trims on whichever ceiling is reached first. Sorted once and walked,
    /// rather than checked twice, so a cache that is over both limits does not
    /// get two passes over the directory.
    private func trimIfNeeded() {
        let all = entries()
        var total = all.reduce(0) { $0 + $1.size }
        guard all.count > maximumEntries || total > maximumBytes else { return }

        var remaining = all.count
        var doomed: [URL] = []
        for entry in all.sorted(by: { $0.accessed < $1.accessed }) {
            guard remaining > maximumEntries || total > maximumBytes else { break }
            doomed.append(entry.url)
            remaining -= 1
            total -= entry.size
        }

        lock.withLock {
            for url in doomed { try? fileManager.removeItem(at: url) }
        }
    }

}
