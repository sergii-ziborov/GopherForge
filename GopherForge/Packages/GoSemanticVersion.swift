import Foundation

/// Just enough semver to sort a version list the way `go list -m -versions`
/// would present it.
///
/// Not a general implementation: modules use a constrained subset, and the one
/// question this has to answer is "which of these is newer". Pre-releases sort
/// below the release they lead to, which is the rule that matters when the
/// newest tag is `v2.0.0-rc.1` and the newest release is `v1.9.4`.
struct GoSemanticVersion: Comparable, Equatable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    /// Everything after `-`, empty for a release.
    let preRelease: String
    let original: String

    init?(_ text: String) {
        guard text.hasPrefix("v") else { return nil }
        var body = String(text.dropFirst())

        // `+incompatible` and other build metadata never affect ordering.
        if let plus = body.firstIndex(of: "+") { body = String(body[body.startIndex..<plus]) }

        var pre = ""
        if let dash = body.firstIndex(of: "-") {
            pre = String(body[body.index(after: dash)...])
            body = String(body[body.startIndex..<dash])
        }

        let parts = body.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty, let major = Int(parts[0]) else { return nil }
        self.major = major
        minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
        preRelease = pre
        original = text
    }

    var isPreRelease: Bool { !preRelease.isEmpty }

    static func < (lhs: GoSemanticVersion, rhs: GoSemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // A pre-release precedes its own release; two pre-releases fall back to
        // string order, which is what semver does for identifiers of one kind.
        if lhs.isPreRelease != rhs.isPreRelease { return lhs.isPreRelease }
        return lhs.preRelease < rhs.preRelease
    }

    /// Anything unparseable keeps its place at the end rather than being
    /// dropped: a version the app cannot order is still one the proxy offers.
    static func sortedNewestFirst(_ versions: [String]) -> [String] {
        let parsed = versions.compactMap { GoSemanticVersion($0) }
        let unparsed = versions.filter { GoSemanticVersion($0) == nil }.sorted()
        return parsed.sorted(by: >).map(\.original) + unparsed
    }

    /// The newest release, ignoring pre-releases unless there is nothing else.
    static func newestStable(_ versions: [String]) -> String? {
        let parsed = versions.compactMap { GoSemanticVersion($0) }
        let releases = parsed.filter { !$0.isPreRelease }
        return (releases.max() ?? parsed.max())?.original
    }
}
