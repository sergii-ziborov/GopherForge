import Foundation

/// One toolchain invocation, expressed entirely in guest paths.
///
/// A step is data: it names the tool, the argv, and the files that have to
/// exist inside the sandbox before it runs. Nothing here touches the file
/// system or the interpreter, which is what makes a build plan something a
/// test can read and assert on rather than something only a device can prove.
struct GoToolStep: Equatable {
    enum Tool: String, Equatable {
        case compile
        case link
        case vet
        case format

        /// `cmd/compile` and `cmd/link` print their errors on **stdout**, not
        /// stderr. That surprises everyone, because `go build` relays them to
        /// stderr and hides it — and driving the tools directly means reading
        /// the stream they actually write to. `vet` uses stderr; `gofmt -l`
        /// uses stdout for the list of files it changed, which is data rather
        /// than diagnostics.
        var writesDiagnosticsToStandardOutput: Bool {
            self == .compile || self == .link
        }
    }

    let tool: Tool
    let arguments: [String]
    /// Guest path to contents, written into the sandbox before the step runs.
    /// Import configurations and generated test mains arrive this way.
    let generatedFiles: [String: String]
    /// What this step is for, in the words the UI would use.
    let label: String
    /// The file this step produces, when it produces one. Carried rather than
    /// parsed back out of the argv, which would make the cache depend on
    /// reading flags correctly.
    var outputPath: String?
    /// Identifies the output's inputs completely, when it can. A step with a
    /// key can be skipped whenever a previous build already produced the same
    /// bytes; a step without one always runs.
    var cacheKey: String?
}

/// An ordered set of steps and what they produce.
struct GoBuildPlan: Equatable {
    /// A program the plan links and the app can then execute.
    struct Product: Equatable {
        let guestPath: String
        /// The package it came from, used to label test output.
        let importPath: String
    }

    let steps: [GoToolStep]
    /// Linked programs, in the order they should be run. A build that only
    /// type-checks has none; a run has one; a test run has one per package
    /// that has tests.
    let products: [Product]

    var isEmpty: Bool { steps.isEmpty }
}

/// Where things live inside the sandbox.
///
/// Intermediate names are flattened rather than nested so no step ever has to
/// create a directory inside the guest: WASI gives the toolchain preopened
/// directories, and a missing parent would fail a build for a reason that has
/// nothing to do with the user's code.
enum GoGuestPath {
    static let work = "/work"
    static let goroot = "/goroot"
    static let cache = "/cache"
    static let temp = "/tmp"

    static let standardLibraryPackages = "\(goroot)/pkg/wasip1_wasm"

    static func source(_ projectRelativePath: String) -> String {
        "\(work)/\(projectRelativePath)"
    }

    static func archive(for importPath: String) -> String {
        "\(temp)/\(flattened(importPath)).a"
    }

    static func standardLibraryArchive(for importPath: String) -> String {
        "\(standardLibraryPackages)/\(importPath).a"
    }

    static func importConfiguration(for importPath: String, suffix: String = "") -> String {
        "\(temp)/\(flattened(importPath))\(suffix).importcfg"
    }

    static func vetConfiguration(for importPath: String) -> String {
        "\(temp)/\(flattened(importPath)).vet.cfg"
    }

    static func vetFacts(for importPath: String) -> String {
        "\(temp)/\(flattened(importPath)).vetx"
    }

    static func generatedTestMain(for importPath: String) -> String {
        "\(temp)/\(flattened(importPath))_testmain.go"
    }

    static func program(for importPath: String, suffix: String) -> String {
        "\(work)/\(flattened(importPath))\(suffix).wasm"
    }

    /// The single output name the run phase produces, kept stable because the
    /// artifact cache and the UI both refer to it.
    static let runProgram = "\(work)/program.wasm"

    /// `example.com/a/b` becomes `example-com_a_b`.
    ///
    /// The separators are doubled before they are reused, so the mapping is
    /// injective: without that, `forge/test` and `forge_test` would flatten to
    /// the same name, and a module with a `test/` directory and an external
    /// test package would quietly compile one over the other.
    static func flattened(_ importPath: String) -> String {
        importPath
            .replacingOccurrences(of: "_", with: "__")
            .replacingOccurrences(of: "-", with: "--")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "-")
    }
}

/// Renders the `packagefile` list both `compile` and `link` read.
enum GoImportConfiguration {
    static func render(_ entries: [String: String]) -> String {
        entries
            .sorted { $0.key < $1.key }
            .map { "packagefile \($0.key)=\($0.value)" }
            .joined(separator: "\n") + "\n"
    }
}
