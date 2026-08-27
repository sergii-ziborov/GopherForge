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
    /// Additional packages, keyed by project-relative path. Empty for a
    /// single-file example; a project's whole point is that this is not.
    var extraFiles: [String: String] = [:]
    /// The module path, which matters once an example has more than one
    /// package: its own packages are imported through it.
    var modulePath: String = "example"
    /// True when the program's job is to produce an image rather than text.
    /// Interactive Go graphics cannot run here — they need a window and a GPU,
    /// and WASI has neither — but a program that draws into a buffer and writes
    /// a PNG runs perfectly, and the app shows what it drew.
    var producesImage: Bool = false
    /// A module the app ships, vendored into this project when it is opened.
    /// The example then builds offline against a real dependency.
    var vendoredModule: VendoredModuleLoader.Bundled?

    var moduleName: String { modulePath }

    var files: [String: String] {
        var all = extraFiles
        all["go.mod"] = GoLanguage.module(modulePath)
        all["main.go"] = source
        guard let vendoredModule else { return all }
        return VendoredModuleLoader().vendoring(vendoredModule, into: all)
    }

    var isProject: Bool { !extraFiles.isEmpty }

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
