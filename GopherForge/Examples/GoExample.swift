import Foundation

/// A small Go program that demonstrates one thing, and that provably runs.
///
/// "Working examples" is a claim, and in this product it is a checked one:
/// `BundledCompilerGateTests` compiles and runs every example in the catalog
/// and asserts it prints exactly `expectedOutput`. An example that stops
/// working fails the build rather than misleading someone.
struct GoExample: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// One sentence: what this shows, not what the code says.
    let summary: String
    /// The point worth taking away, in the words the course uses.
    let takeaway: String
    /// Concept tags, shared with the compiler and the review scheduler, so an
    /// example can be offered for something the learner keeps getting wrong.
    let conceptTags: [String]
    let source: String
    /// Exactly what the program prints, including the trailing newline.
    let expectedOutput: String

    var moduleName: String { "example" }

    var files: [String: String] {
        [
            "go.mod": GoLanguage.module(moduleName),
            "main.go": source,
        ]
    }

    /// Ready to open in the workspace and run.
    func project() -> GopherForgeProject {
        GopherForgeProject(
            name: title,
            files: files,
            entryFile: "main.go",
            provenance: .template()
        )
    }

    func snapshot() -> GoSourceSnapshot {
        GoSourceSnapshot(files: files, packagePattern: ".", entryFile: "main.go")
    }
}
