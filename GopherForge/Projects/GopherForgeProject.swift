import Foundation

/// A Go project as the app holds it: paths to contents, plus where it came from.
struct GopherForgeProject: Codable, Equatable, Sendable {
    struct Provenance: Codable, Equatable, Sendable {
        enum Source: String, Codable, Sendable {
            case files
            case github
            case gopherForgePackage
            case template
        }

        let source: Source
        let owner: String?
        let repository: String?
        let reference: String?
        let commit: String?
        let importedAt: Date

        static func files(at date: Date = Date()) -> Provenance {
            Provenance(
                source: .files,
                owner: nil,
                repository: nil,
                reference: nil,
                commit: nil,
                importedAt: date
            )
        }

        static func template(at date: Date = Date()) -> Provenance {
            Provenance(
                source: .template,
                owner: nil,
                repository: nil,
                reference: nil,
                commit: nil,
                importedAt: date
            )
        }
    }

    let name: String
    let files: [String: String]
    let entryFile: String
    let provenance: Provenance?

    /// The same project under another name.
    ///
    /// `name` stays a `let` so nothing inside the project can rename it behind
    /// the library's back; this is the one door, and the library is what walks
    /// through it.
    func renamed(to newName: String) -> GopherForgeProject {
        GopherForgeProject(
            name: newName,
            files: files,
            entryFile: entryFile,
            provenance: provenance
        )
    }

    var module: GoModule? {
        files["go.mod"].flatMap(GoModParser.parse)
    }

    var goFileCount: Int {
        files.keys.count { $0.hasSuffix(".go") }
    }

    var testFileCount: Int {
        files.keys.count { $0.hasSuffix("_test.go") }
    }

    /// Every directory that holds at least one `.go` file, which is what Go
    /// calls a package.
    var packageDirectories: [String] {
        var directories: Set<String> = []
        for path in files.keys where path.hasSuffix(".go") {
            let components = path.split(separator: "/").dropLast()
            directories.insert(components.isEmpty ? "." : components.joined(separator: "/"))
        }
        return directories.sorted()
    }

    func snapshot(packagePattern: String = "./...") -> GoSourceSnapshot {
        GoSourceSnapshot(files: files, packagePattern: packagePattern, entryFile: entryFile)
    }
}
