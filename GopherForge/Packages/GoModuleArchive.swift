import Foundation

/// Reads a module zip into memory, safely.
///
/// A module archive is an untrusted file from the network, so every entry is
/// checked before it is kept: the name has to sit under the module's own
/// `path@version/` prefix, contain no traversal, and the whole thing has to
/// stay inside a budget. Nothing is written to disk during this — the files go
/// into the project, and the project decides where that is.
struct GoModuleArchive {
    enum ArchiveError: Error, Equatable {
        case unreadable
        case entryOutsideModule(String)
        case tooManyFiles(Int)
        case tooLarge(Int)
        case emptyModule
    }

    static let maximumFiles = 4_000
    /// `modernc.org/sqlite` unpacks to about 146 MB and `google.golang.org/api`
    /// to about 380 MB. Both fit. A larger archive is still refused.
    static let maximumUncompressedBytes = 512 * 1024 * 1024
    /// Above this, the zip is hashed one file at a time and only the package
    /// that was imported is kept. Holding a 380 MB module as strings freezes
    /// the phone.
    private static let streamingThreshold = 160 * 1024 * 1024
    /// Go source kept from one module when the archive is larger than the
    /// streaming threshold, or when the build-relevant source itself is huge.
    private static let keptSourceBudget = 48 * 1024 * 1024

    /// Names exactly as they appear in the archive, mapped to their bytes.
    /// The `h1:` hash is computed over precisely this, unless `digest` holds
    /// a hash that was computed before unused files were dropped.
    let entries: [String: Data]
    let reference: GoModuleReference
    private let digest: String?

    init(data: Data, reference: GoModuleReference, neededImport: String? = nil) throws {
        let catalog: [ZipArchive.Entry]
        do {
            catalog = try ZipArchive.catalog(in: data).filter { !$0.isDirectory }
        } catch {
            throw ArchiveError.unreadable
        }
        guard catalog.count <= Self.maximumFiles else {
            throw ArchiveError.tooManyFiles(catalog.count)
        }
        let declared = catalog.reduce(0) { $0 + $1.uncompressedSize }
        guard declared <= Self.maximumUncompressedBytes else {
            throw ArchiveError.tooLarge(declared)
        }
        for entry in catalog {
            guard Self.isSafe(entry.path, under: reference.archivePrefix) else {
                throw ArchiveError.entryOutsideModule(entry.path)
            }
        }

        if declared <= Self.streamingThreshold {
            let unpacked: [String: Data]
            do {
                unpacked = try ZipArchive.files(from: data, limit: Self.maximumUncompressedBytes)
            } catch ZipArchive.ZipError.tooLarge(let bytes) {
                throw ArchiveError.tooLarge(bytes)
            } catch {
                throw ArchiveError.unreadable
            }
            guard !unpacked.isEmpty else { throw ArchiveError.emptyModule }
            self.entries = unpacked
            self.digest = nil
        } else {
            let loaded = try Self.stream(data, catalog: catalog, reference: reference, neededImport: neededImport)
            self.entries = loaded.entries
            self.digest = loaded.digest
        }
        self.reference = reference
    }

    /// The archive's own hash, to be compared with the checksum database's.
    func hash() throws -> String {
        if let digest { return digest }
        return try GoModuleHash.hash1(files: entries)
    }

    /// Files the build actually needs, keyed by their path relative to the
    /// module root.
    ///
    /// Tests, testdata and hidden files are dropped: a vendored dependency is
    /// compiled, not tested, and `go mod vendor` drops them for the same
    /// reason. On a phone the difference is most of the download. Files for
    /// another operating system are dropped too. A module that is still huge
    /// after that keeps the imported package and the packages it imports.
    func vendoredFiles(neededImport: String? = nil) -> [String: String] {
        let constraint = GoBuildConstraint(environment: .wasip1(goVersion: "1.27.1"))
        var files: [String: String] = [:]
        for (name, data) in entries {
            let relative = String(name.dropFirst(reference.archivePrefix.count))
            guard Self.isVendored(relative) else { continue }
            guard let text = String(data: data, encoding: .utf8) else { continue }
            if relative.hasSuffix(".go"), !constraint.includes(path: relative, source: text) {
                continue
            }
            files[relative] = text
        }
        let goBytes = files.reduce(0) { partial, item in
            item.key.hasSuffix(".go") ? partial + item.value.utf8.count : partial
        }
        guard goBytes > Self.keptSourceBudget, let neededImport else { return files }
        let keep = Self.closure(of: neededImport, modulePath: reference.path, in: files)
        guard !keep.isEmpty else { return files }
        return files.filter { path, _ in !path.hasSuffix(".go") || keep.contains(path) }
    }

    private static func stream(
        _ data: Data,
        catalog: [ZipArchive.Entry],
        reference: GoModuleReference,
        neededImport: String?
    ) throws -> (entries: [String: Data], digest: String) {
        var lines: [(name: String, sha256Hex: String)] = []
        for entry in catalog {
            let bytes = try extract(entry, from: data)
            lines.append((entry.path, GoModuleHash.sha256Hex(bytes)))
        }
        let digest = try GoModuleHash.hash1(lines: lines)
        let kept = try selectedEntries(
            catalog: catalog,
            reference: reference,
            neededImport: neededImport,
            data: data
        )
        guard !kept.isEmpty else { throw ArchiveError.emptyModule }
        return (kept, digest)
    }

    private static func selectedEntries(
        catalog: [ZipArchive.Entry],
        reference: GoModuleReference,
        neededImport: String?,
        data: Data
    ) throws -> [String: Data] {
        let constraint = GoBuildConstraint(environment: .wasip1(goVersion: "1.27.1"))
        func relative(_ path: String) -> String {
            String(path.dropFirst(reference.archivePrefix.count))
        }
        let goEntries = catalog.filter { entry in
            let path = relative(entry.path)
            return path.hasSuffix(".go") && constraint.matchesFileName(path) && isVendored(path)
        }
        let goBytes = goEntries.reduce(0) { $0 + $1.uncompressedSize }
        let wanted: Set<String>
        if goBytes <= keptSourceBudget || neededImport == nil {
            wanted = Set(goEntries.map { relative($0.path) })
        } else {
            wanted = try closureEntries(
                of: neededImport ?? "",
                modulePath: reference.path,
                catalog: goEntries,
                data: data,
                relative: relative
            )
        }
        var entries: [String: Data] = [:]
        for entry in catalog {
            let path = relative(entry.path)
            let keep = wanted.contains(path)
                || path == "go.mod"
                || path.hasPrefix("LICENSE")
                || path.hasPrefix("LICENCE")
                || path == "NOTICE"
            guard keep else { continue }
            entries[entry.path] = try extract(entry, from: data)
        }
        return entries
    }

    /// Go files of `importPath` and of the packages those files import inside
    /// this module. Other packages in a giant module stay out of the project.
    private static func closure(
        of importPath: String,
        modulePath: String,
        in files: [String: String]
    ) -> Set<String> {
        var keep: Set<String> = []
        var pending = [importPath]
        var seen: Set<String> = []
        while let current = pending.popLast() {
            guard seen.insert(current).inserted else { continue }
            guard current == modulePath || current.hasPrefix(modulePath + "/") else { continue }
            let directory = current == modulePath ? "" : String(current.dropFirst(modulePath.count + 1))
            for (path, text) in files where path.hasSuffix(".go") {
                let parent = path.split(separator: "/").dropLast().joined(separator: "/")
                guard parent == directory else { continue }
                keep.insert(path)
                for imported in GoSourceHeader.parse(text).imports where !seen.contains(imported) {
                    pending.append(imported)
                }
            }
        }
        return keep
    }

    private static func closureEntries(
        of importPath: String,
        modulePath: String,
        catalog: [ZipArchive.Entry],
        data: Data,
        relative: (String) -> String
    ) throws -> Set<String> {
        var texts: [String: String] = [:]
        var pending = [importPath]
        var seen: Set<String> = []
        var keep: Set<String> = []
        while let current = pending.popLast() {
            guard seen.insert(current).inserted else { continue }
            guard current == modulePath || current.hasPrefix(modulePath + "/") else { continue }
            let directory = current == modulePath ? "" : String(current.dropFirst(modulePath.count + 1))
            for entry in catalog {
                let path = relative(entry.path)
                let parent = path.split(separator: "/").dropLast().joined(separator: "/")
                guard parent == directory else { continue }
                let text: String
                if let cached = texts[path] {
                    text = cached
                } else {
                    let bytes = try extract(entry, from: data)
                    guard let decoded = String(data: bytes, encoding: .utf8) else { continue }
                    texts[path] = decoded
                    text = decoded
                }
                keep.insert(path)
                for imported in GoSourceHeader.parse(text).imports where !seen.contains(imported) {
                    pending.append(imported)
                }
            }
        }
        return keep
    }

    private static func extract(_ entry: ZipArchive.Entry, from data: Data) throws -> Data {
        do {
            return try ZipArchive.extract(entry, from: data, remaining: max(entry.uncompressedSize, 1))
        } catch ZipArchive.ZipError.tooLarge(let bytes) {
            throw ArchiveError.tooLarge(bytes)
        } catch {
            throw ArchiveError.unreadable
        }
    }

    static func isVendored(_ relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/").map(String.init)
        guard let name = components.last else { return false }
        if components.contains(where: { $0 == "testdata" || $0.hasPrefix("_") || $0.hasPrefix(".") }) {
            return false
        }
        if name.hasSuffix("_test.go") { return false }
        if name.hasSuffix(".go") || name == "go.mod" { return true }
        // Licences travel with the code, because vendoring is redistribution.
        return name.hasPrefix("LICENSE") || name.hasPrefix("LICENCE") || name.hasPrefix("NOTICE")
    }

    static func isSafe(_ name: String, under prefix: String) -> Bool {
        guard name.hasPrefix(prefix), !name.hasSuffix("/") else { return false }
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

/// The size a source file may be and still be something a person — or a
/// reviewer — can read.
///
/// Guideline 2.5.2's teaching exception is that the user's own imported
/// source is viewable. Five hundred lines is the ceiling for notes and
/// pages. Go source has a higher ceiling, because generated files are part
/// of the build. Installed packages are vendored as published — a real
/// module is often longer than either, and refusing it would make Add
/// packages refuse most of the ecosystem.
enum SourceFileLimit {
    static let maximumLines = 500
    /// Generated Go — protobuf, tables — is often longer than a lesson, and
    /// dropping it is how an imported repository stops compiling.
    static let maximumGoLines = 20_000

    static func isBuildEssential(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return path.hasSuffix(".go") || name == "go.mod" || name == "go.sum"
    }

    static func exceedsImportLimit(_ text: String, path: String) -> Bool {
        lineCount(of: text) > (isBuildEssential(path) ? maximumGoLines : maximumLines)
    }

    static func lineCount(of text: String) -> Int {
        if text.isEmpty { return 0 }
        return text.reduce(1) { count, character in
            character == "\n" ? count + 1 : count
        }
    }

    static func exceedsLimit(_ text: String) -> Bool {
        lineCount(of: text) > maximumLines
    }

    /// Own project files only. Vendored modules are packages in the sidebar,
    /// not pages a reviewer is asked to read.
    static func oversizedOwnFiles(in files: [String: String]) -> [String] {
        files.keys.sorted().filter { path in
            guard !GoVendorWriter.isVendoredPath(path) else { return false }
            return exceedsLimit(files[path] ?? "")
        }
    }
}
