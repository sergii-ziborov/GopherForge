import XCTest
@testable import GopherForge

/// What the bundled toolchain proves about content this app ships and about
/// code a user installs.
///
/// Separated from the toolchain's own gates because these check claims rather
/// than capability: that every published example really prints what it says,
/// and that a vendored dependency really compiles. Same scheme, same
/// requirement — a missing toolchain fails them rather than skipping them.
final class BundledContentGateTests: XCTestCase {
    private var compiler: WasmGoCompiler!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GOPHERFORGE_RUN_COMPILER_GATE"] == "1",
            "Run the GopherForgeCompilerGate scheme to execute the bundled-toolchain gates."
        )
        compiler = WasmGoCompiler()
        compiler.clearBuildCache()
    }

    /// Every example in the library, compiled and run.
    ///
    /// "Working examples" is a claim, and this is what makes it a checked one.
    /// An example that stops compiling, or that quietly starts printing
    /// something else, fails here rather than teaching someone the wrong thing.
    func testEveryExampleCompilesAndPrintsWhatItClaims() async throws {
        XCTAssertFalse(GoExampleLibrary.all.isEmpty, "the library should not be empty")

        var failures: [String] = []
        for example in GoExampleLibrary.all {
            let result = await compiler.run(project: example.snapshot())
            guard result.succeeded else {
                failures.append("\(example.id): did not run — \(report(result))")
                continue
            }
            if result.stdout != example.expectedOutput {
                failures.append(
                    """
                    \(example.id): printed something else
                    expected: \(example.expectedOutput.debugDescription)
                    actual:   \(result.stdout.debugDescription)
                    """
                )
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n\n"))
    }

    func testEveryGinSiteRunsWithTheBundledCompiler() async {
        for example in GoExampleLibrarySites.all {
            let result = await compiler.run(project: example.snapshot())
            XCTAssertTrue(result.succeeded, "\(example.id): \(report(result))")
            XCTAssertEqual(result.stdout, example.expectedOutput, example.id)
        }
    }

    @MainActor
    func testGinProjectRunsWhenOpenedInWorkspace() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "gin-workspace-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = WorkspaceModel(
            compiler: compiler,
            library: ProjectLibrary(storageURL: root.appending(path: "projects.json"))
        )
        await workspace.prepare()
        let example = GoExampleProjectGinCafe.cafe
        XCTAssertTrue(workspace.open(example.project()))
        await workspace.run(.run)
        XCTAssertTrue(workspace.lastResult?.succeeded == true, workspace.lastResult?.detail ?? "no result")
        XCTAssertEqual(workspace.lastResult?.stdout, example.expectedOutput)
        XCTAssertNotNil(workspace.sitePreviewURL)

        let previousOpening = workspace.projectGeneration
        XCTAssertTrue(workspace.open(ProjectTemplate.commandLineTool.project(named: "Fresh")))
        XCTAssertGreaterThan(workspace.projectGeneration, previousOpening)
        XCTAssertNil(workspace.lastResult)
        XCTAssertEqual(workspace.selectedFile, "main.go")
    }

    /// Identifiers are how an example is referred to from a concept or a
    /// review item, so two examples sharing one is a silent redirect.
    func testExampleIdentifiersAreUnique() {
        let ids = GoExampleLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate example ids in \(ids)")
    }

    /// A graphic example must deliver the PNG it claims to draw, not merely
    /// print a success line while leaving the Output pane empty.
    func testEveryGraphicExampleProducesAPNG() async {
        for example in GoExampleLibraryGraphics.all + GoExampleLibraryGraphicsMore.all {
            let result = await compiler.run(project: example.snapshot())
            XCTAssertTrue(result.succeeded, "\(example.id): \(report(result))")
            XCTAssertFalse(result.artifacts.images.isEmpty, "\(example.id): no image captured")
            for image in result.artifacts.images {
                XCTAssertTrue(
                    image.data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
                    "\(example.id): \(image.name) is not a PNG"
                )
            }
        }
    }

    /// A vendored dependency, compiled by the real toolchain.
    ///
    /// This is the half of package installation that has nothing to do with the
    /// network: once a module's source is under `vendor/`, the build has to
    /// find it under its published import path rather than under this module's.
    /// No download happens here — the vendored package is written by hand,
    /// which is exactly what makes this a test of the build and not of a proxy.
    func testAVendoredPackageIsCompiledUnderItsPublishedImportPath() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": "module playground\n\ngo 1.24\n\nrequire (\n\texample.com/greet v1.2.0\n)\n",
                "main.go": "package main\n\nimport (\n\t\"fmt\"\n\n\t\"example.com/greet\"\n)\n\n"
                    + "func main() { fmt.Println(greet.Message(\"gopher\")) }\n",
                "vendor/example.com/greet/greet.go":
                    "package greet\n\nfunc Message(name string) string { return \"hello, \" + name }\n",
                "vendor/modules.txt": "# example.com/greet v1.2.0\n## explicit\nexample.com/greet\n",
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let result = await compiler.run(project: snapshot)

        XCTAssertTrue(result.succeeded, report(result))
        XCTAssertTrue(result.stdout.contains("hello, gopher"), report(result))
    }

    /// The offline promise, stated as a test: an import that is neither in the
    /// module, nor vendored, nor in the bundled standard library is refused
    /// before any tool runs — with a sentence rather than a linker error.
    func testAnUninstalledImportIsRefusedWithSomethingReadable() async throws {
        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": "module playground\n\ngo 1.24\n",
                "main.go": "package main\n\nimport \"github.com/google/uuid\"\n\n"
                    + "func main() { _ = uuid.New() }\n",
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let result = await compiler.build(project: snapshot)

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.detail.contains("github.com/google/uuid"),
            "the message should name the import, got: \(result.detail)"
        )
    }


    /// A gate that fails has to say why.
    private func report(_ result: CompilationResult) -> String {
        """
        \(result.detail)
        stdout: \(result.stdout)
        stderr: \(result.stderr)
        diagnostics: \(result.diagnostics.map(\.message))
        """
    }
}
