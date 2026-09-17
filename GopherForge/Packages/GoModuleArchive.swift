import Foundation
import ZIPFoundation

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
        case fileTooLong(String)
        case emptyModule
    }

    static let maximumFiles = 4_000
    static let maximumUncompressedBytes = 48 * 1024 * 1024

    /// Names exactly as they appear in the archive, mapped to their bytes.
    /// The `h1:` hash is computed over precisely this.
    let entries: [String: Data]
    let reference: GoModuleReference

    init(data: Data, reference: GoModuleReference) throws {
        guard let archive = try? Archive(data: data, accessMode: .read, pathEncoding: nil) else {
            throw ArchiveError.unreadable
        }

        var entries: [String: Data] = [:]
        var total = 0

        for entry in archive where entry.type == .file {
            let name = entry.path
            guard Self.isSafe(name, under: reference.archivePrefix) else {
                throw ArchiveError.entryOutsideModule(name)
            }
            guard entries.count < Self.maximumFiles else {
                throw ArchiveError.tooManyFiles(entries.count)
            }

            var bytes = Data()
            _ = try? archive.extract(entry, bufferSize: 64 * 1024, skipCRC32: false) { chunk in
                bytes.append(chunk)
            }
            total += bytes.count
            guard total <= Self.maximumUncompressedBytes else {
                throw ArchiveError.tooLarge(total)
            }
            entries[name] = bytes
        }

        guard !entries.isEmpty else { throw ArchiveError.emptyModule }
        self.entries = entries
        self.reference = reference
    }

    /// The archive's own hash, to be compared with the checksum database's.
    func hash() throws -> String {
        try GoModuleHash.hash1(files: entries)
    }

    /// Files the build actually needs, keyed by their path relative to the
    /// module root.
    ///
    /// Tests, testdata and hidden files are dropped: a vendored dependency is
    /// compiled, not tested, and `go mod vendor` drops them for the same
    /// reason. On a phone the difference is most of the download.
    func vendoredFiles() throws -> [String: String] {
        var files: [String: String] = [:]
        for (name, data) in entries {
            let relative = String(name.dropFirst(reference.archivePrefix.count))
            guard Self.isVendored(relative) else { continue }
            guard let text = String(data: data, encoding: .utf8) else { continue }
            // Teaching-sized source is the 2.5.2 story: a file a reviewer
            // cannot read in one sitting is a dump, not a lesson. Licences
            // stay as the author wrote them.
            if relative.hasSuffix(".go"), SourceFileLimit.exceedsLimit(text) {
                throw ArchiveError.fileTooLong(relative)
            }
            files[relative] = text
        }
        return files
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
/// Guideline 2.5.2's teaching exception is that downloaded code is viewable
/// and editable. A thousand-line dump fails that in practice even when the
/// editor will open it. Five hundred lines is the ceiling this app will
/// import, vendor or keep as the user's own file.
enum SourceFileLimit {
    static let maximumLines = 500

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
