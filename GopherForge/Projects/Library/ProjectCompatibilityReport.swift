import Foundation

/// What the app can and cannot do with a project it was just handed.
///
/// The point is to say so before the user hits Build, and to say it in terms of
/// this product's actual boundaries rather than generic warnings. cgo and
/// network module fetching are out of scope in this phase, and a project that
/// needs either should learn that immediately.
struct ProjectCompatibilityReport: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case ready
        case inspect
    }

    let status: Status
    let goFiles: Int
    let packages: Int
    let requirements: Int
    let notes: [String]

    static func scan(_ project: GopherForgeProject) -> ProjectCompatibilityReport {
        var notes: [String] = []
        let modules = project.files
            .filter { $0.key == "go.mod" || $0.key.hasSuffix("/go.mod") }
            .compactMap { GoModParser.parse($0.value) }
        let requirementCount = modules.reduce(0) { $0 + $1.requirements.count }
        let hasVendor = project.files.keys.contains { $0.hasPrefix("vendor/") }

        if requirementCount > 0, !hasVendor {
            notes.append("Module downloads are off in this build; vendor the dependencies to build offline.")
        }
        if usesCgo(project) {
            notes.append("cgo is not supported: this package needs a native C toolchain.")
        }
        if project.files.keys.contains(where: { $0 == "go.work" || $0.hasSuffix("/go.work") }) {
            notes.append("Workspace detected; GopherForge opened the discovered module root.")
        }
        if modules.count > 1 {
            notes.append("Several modules found; only the root module is built.")
        }
        if !declaresMainPackage(project) {
            notes.append("No main package found; Run needs a package main with a func main.")
        }

        return ProjectCompatibilityReport(
            status: notes.isEmpty ? .ready : .inspect,
            goFiles: project.goFileCount,
            packages: project.packageDirectories.count,
            requirements: requirementCount,
            notes: notes
        )
    }

    /// `import "C"` is the only way cgo enters a file, and it must appear in
    /// the import block rather than anywhere in the text.
    private static func usesCgo(_ project: GopherForgeProject) -> Bool {
        project.files.contains { path, contents in
            guard path.hasSuffix(".go") else { return false }
            return contents.split(whereSeparator: \.isNewline).contains { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed == #"import "C""# || trimmed == #""C""#
            }
        }
    }

    private static func declaresMainPackage(_ project: GopherForgeProject) -> Bool {
        project.files.contains { path, contents in
            guard path.hasSuffix(".go") else { return false }
            return contents.split(whereSeparator: \.isNewline).contains {
                $0.trimmingCharacters(in: .whitespaces) == "package main"
            }
        }
    }
}
