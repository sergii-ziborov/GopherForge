import Foundation
import CryptoKit

/// Go's `h1:` module hash, computed here so a download can be checked before
/// anything is written into a project.
///
/// The algorithm is `golang.org/x/mod/sumdb/dirhash.Hash1` and it is short
/// enough to state exactly: SHA-256 over the lines `"<sha256 hex>  <name>\n"`
/// for every file, sorted by name, base64-encoded and prefixed with `h1:`.
/// Two spaces between the hash and the name, and the names are the paths as
/// they appear inside the module zip, including the `module@version/` prefix.
///
/// A `GoModuleHashTests` fixture pins this against a value produced by the
/// algorithm as Go specifies it, and that implementation was in turn checked
/// against a published `go.sum` hash for a real module.
enum GoModuleHash {
    enum HashError: Error, Equatable {
        /// Go refuses these too: a newline in a name would make the summary
        /// ambiguous, and an ambiguous summary is a forgeable one.
        case nameContainsNewline(String)
    }

    /// `files` maps the name inside the archive to its bytes.
    static func hash1(files: [String: Data]) throws -> String {
        var summary = Data()
        for name in files.keys.sorted() {
            guard !name.contains("\n") else { throw HashError.nameContainsNewline(name) }
            let digest = SHA256.hash(data: files[name] ?? Data())
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            summary.append(Data("\(hex)  \(name)\n".utf8))
        }
        return "h1:" + Data(SHA256.hash(data: summary)).base64EncodedString()
    }
}

/// A module and the exact version of it being installed.
struct GoModuleReference: Equatable, Hashable, Sendable, Codable {
    let path: String
    let version: String

    var id: String { "\(path)@\(version)" }

    /// The name a module's files carry inside its zip, which is also the prefix
    /// the hash is computed over.
    var archivePrefix: String { "\(path)@\(version)/" }

    /// Rejects what the proxy would reject anyway, before a request is made.
    ///
    /// The path is checked because it becomes a URL and then a directory name;
    /// a path with `..` in it would escape the vendor directory when written.
    static func validated(path: String, version: String) -> GoModuleReference? {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 2,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              path.first != "/",
              !path.contains(" "),
              components[0].contains("."),
              isVersionLike(version)
        else {
            return nil
        }
        return GoModuleReference(path: path, version: version)
    }

    /// `v1.2.3`, with an optional pre-release or `+incompatible` suffix, and
    /// the pseudo-versions the proxy hands back for untagged commits.
    private static func isVersionLike(_ version: String) -> Bool {
        guard version.hasPrefix("v"), version.count > 1 else { return false }
        let body = version.dropFirst()
        guard let major = body.split(separator: ".").first, major.allSatisfy(\.isNumber) else {
            return false
        }
        return !version.contains("/") && !version.contains(" ")
    }
}
