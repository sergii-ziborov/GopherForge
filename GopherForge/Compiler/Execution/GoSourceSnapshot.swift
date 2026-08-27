import Foundation

/// An immutable picture of a Go project at the moment a phase was requested.
///
/// The compiler never reads the editor's live state: a snapshot is taken on the
/// main actor and handed over, so a keystroke during a build cannot change what
/// was compiled or invalidate the cache key that was already computed.
struct GoSourceSnapshot: Sendable, Equatable {
    /// Project-relative path to contents. Always includes `go.mod` for a
    /// module build; a single-file lesson may omit it.
    let files: [String: String]
    /// The package pattern the phase applies to, for example `./...` for a
    /// whole module or `.` for the main package alone.
    let packagePattern: String
    /// The file the editor considers active, used to attribute diagnostics
    /// that arrive without a usable path.
    let entryFile: String

    init(files: [String: String], packagePattern: String = "./...", entryFile: String = "main.go") {
        self.files = files
        self.packagePattern = packagePattern
        self.entryFile = entryFile
    }

    /// A single-file program wrapped in the smallest module that builds.
    static func singleFile(_ source: String, moduleName: String = "playground") -> GoSourceSnapshot {
        GoSourceSnapshot(
            files: [
                "go.mod": GoLanguage.module(moduleName),
                "main.go": source,
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )
    }

    /// Source lines by file, so a diagnostic can show the line it points at
    /// without the UI having to re-read the project.
    var sourceLines: [String: [String]] {
        files.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.components(separatedBy: "\n")
        }
    }

    var goFileCount: Int {
        files.keys.count { $0.hasSuffix(".go") }
    }

    var hasTests: Bool {
        files.keys.contains { $0.hasSuffix("_test.go") }
    }
}
