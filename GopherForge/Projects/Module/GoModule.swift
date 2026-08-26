import Foundation

/// A parsed `go.mod`.
///
/// The app understands modules without promising unrestricted `go get`: it
/// reads what a project declares so the UI can show it, and the build runs
/// against whatever is already vendored or bundled.
struct GoModule: Equatable, Sendable {
    struct Requirement: Equatable, Sendable, Identifiable {
        let path: String
        let version: String
        /// `// indirect` marks a dependency no package here imports directly.
        /// It matters in the UI: an indirect requirement is not something the
        /// learner chose.
        let isIndirect: Bool

        var id: String { path }

        /// The last path element, which is what a reader recognises.
        var displayName: String {
            path.split(separator: "/").last.map(String.init) ?? path
        }
    }

    struct Replacement: Equatable, Sendable, Identifiable {
        let path: String
        let replacement: String
        var id: String { path }

        /// A local replacement is the only kind that can resolve offline.
        var isLocal: Bool {
            replacement.hasPrefix("./") || replacement.hasPrefix("../") || replacement.hasPrefix("/")
        }
    }

    let modulePath: String
    /// The language version the module targets, for example `1.27`.
    let goVersion: String?
    let toolchain: String?
    let requirements: [Requirement]
    let replacements: [Replacement]

    var displayName: String {
        modulePath.split(separator: "/").last.map(String.init) ?? modulePath
    }

    var directRequirements: [Requirement] {
        requirements.filter { !$0.isIndirect }
    }

    /// Whether a build could succeed with no network and nothing vendored.
    var isSelfContained: Bool {
        requirements.allSatisfy { requirement in
            replacements.first { $0.path == requirement.path }?.isLocal ?? false
        }
    }

    static func minimal(modulePath: String, goVersion: String = "1.27") -> GoModule {
        GoModule(
            modulePath: modulePath,
            goVersion: goVersion,
            toolchain: nil,
            requirements: [],
            replacements: []
        )
    }

    func rendered() -> String {
        var lines = ["module \(modulePath)", ""]
        if let goVersion { lines.append("go \(goVersion)") }
        if let toolchain { lines.append("toolchain \(toolchain)") }
        if !requirements.isEmpty {
            lines.append("")
            lines.append("require (")
            for requirement in requirements.sorted(by: { $0.path < $1.path }) {
                let indirect = requirement.isIndirect ? " // indirect" : ""
                lines.append("\t\(requirement.path) \(requirement.version)\(indirect)")
            }
            lines.append(")")
        }
        for replacement in replacements.sorted(by: { $0.path < $1.path }) {
            lines.append("")
            lines.append("replace \(replacement.path) => \(replacement.replacement)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
