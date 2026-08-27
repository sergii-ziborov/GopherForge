import Foundation
import CryptoKit

/// Identifies everything that decides a compile step's output.
///
/// Editing one file in a project should recompile one package, not all of them.
/// That is a nicety on a laptop and the difference between usable and not on a
/// phone, where a vendored dependency can be a dozen packages that have not
/// changed since they were installed.
///
/// The key covers exactly what the output depends on: the toolchain, the
/// language version, the package's own identity and sources, and — recursively
/// — the keys of everything it imports. A dependency that changes changes every
/// key above it, which is the property that makes skipping a step safe.
enum GoStepFingerprint {
    static func key(
        toolchainTag: String,
        languageVersion: String,
        packagePath: String,
        sources: [String: String],
        dependencyKeys: [String]
    ) -> String {
        var hasher = SHA256()
        for field in ["v1", toolchainTag, languageVersion, packagePath] {
            hasher.update(data: Data(field.utf8))
            hasher.update(data: Data([0]))
        }
        for path in sources.keys.sorted() {
            hasher.update(data: Data(path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data((sources[path] ?? "").utf8))
            hasher.update(data: Data([0]))
        }
        // Sorted, because import order is not part of what is compiled.
        for key in dependencyKeys.sorted() {
            hasher.update(data: Data(key.utf8))
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
