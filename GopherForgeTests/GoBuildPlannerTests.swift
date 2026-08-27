import XCTest
@testable import GopherForge

/// The build strategy, asserted as data.
///
/// The app plans a build itself because `cmd/go` cannot run under WASI, and the
/// payoff for that is here: the ordering, the import configurations and the
/// generated test main are values a test can read without a compiler, a
/// simulator or a device.
final class GoBuildPlannerTests: XCTestCase {
    private let standardLibrary: Set<String> = [
        "fmt", "os", "strings", "testing", "testing/internal/testdeps",
    ]

    private func planner(modulePath: String = "example.com/forge") -> GoBuildPlanner {
        GoBuildPlanner(
            modulePath: modulePath,
            languageVersion: "go1.24",
            standardLibrary: standardLibrary
        )
    }

    private let helloWorld = [
        "go.mod": "module example.com/forge\n\ngo 1.24\n",
        "main.go": "package main\n\nimport \"fmt\"\n\nfunc main() { fmt.Println(\"hi\") }\n",
    ]

    // MARK: - Build and run

    func testRunCompilesThenLinks() throws {
        let plan = try planner().plan(phase: .run, files: helloWorld)

        XCTAssertEqual(plan.steps.map(\.tool), [.compile, .link])
        XCTAssertEqual(plan.products.count, 1)
        XCTAssertEqual(plan.products.first?.guestPath, GoGuestPath.runProgram)
    }

    /// The linker looks up `main.main` by package path. Compiling the entry
    /// point under the module's import path instead produces "function main is
    /// undeclared in the main package", which took a gate run to find.
    func testTheEntryPointIsCompiledAsPackageMain() throws {
        let plan = try planner().plan(phase: .run, files: helloWorld)
        let compile = try XCTUnwrap(plan.steps.first)

        XCTAssertEqual(argument(after: "-p", in: compile.arguments), "main")
    }

    /// In a test binary the entry point is the generated main, so the package
    /// under test keeps its own import path even when it is `package main` —
    /// otherwise the generated main could not import it.
    func testAPackageUnderTestKeepsItsImportPathEvenWhenItIsMain() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\n\nfunc Reverse(s string) string { return s }\n\nfunc main() {}\n",
            "main_test.go": "package main\n\nimport \"testing\"\n\nfunc TestReverse(t *testing.T) {}\n",
        ]

        let plan = try planner().plan(phase: .test, files: files)
        let compiledPaths = plan.steps
            .filter { $0.tool == .compile }
            .compactMap { argument(after: "-p", in: $0.arguments) }

        XCTAssertTrue(compiledPaths.contains("example.com/forge"))
        XCTAssertEqual(
            compiledPaths.last, "main",
            "the generated test main is the entry point the linker resolves"
        )
    }

    /// The archive the linker is handed has to be the one just compiled, and it
    /// has to be named `main` in the configuration. A mismatch links nothing.
    func testTheLinkedArchiveIsTheOneCompiled() throws {
        let plan = try planner().plan(phase: .run, files: helloWorld)
        let compile = try XCTUnwrap(plan.steps.first)
        let link = try XCTUnwrap(plan.steps.last)

        let output = try XCTUnwrap(argument(after: "-o", in: compile.arguments))
        XCTAssertTrue(link.arguments.contains(output), "the link step should consume \(output)")

        let configuration = try XCTUnwrap(link.generatedFiles.values.first)
        XCTAssertTrue(configuration.contains("packagefile main=\(output)"))
        XCTAssertFalse(
            configuration.contains("packagefile example.com/forge="),
            "nothing can import a main package, so nothing should name its archive"
        )
    }

    func testDependenciesAreCompiledBeforeTheirImporters() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": """
            package main

            import (
            \t"fmt"

            \t"example.com/forge/internal/greet"
            )

            func main() { fmt.Println(greet.Message()) }
            """,
            "internal/greet/greet.go": "package greet\n\nfunc Message() string { return \"hi\" }\n",
        ]

        let plan = try planner().plan(phase: .build, files: files)
        let compiled = plan.steps.filter { $0.tool == .compile }.compactMap {
            argument(after: "-p", in: $0.arguments)
        }

        XCTAssertEqual(compiled, ["example.com/forge/internal/greet", "main"])
    }

    /// The importer's configuration has to name the dependency's archive, or
    /// the compiler cannot resolve the import it was just told about.
    func testAnImporterSeesItsDependencyInTheImportConfiguration() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\n\nimport \"example.com/forge/greet\"\n\nfunc main() { greet.Say() }\n",
            "greet/greet.go": "package greet\n\nfunc Say() {}\n",
        ]

        let plan = try planner().plan(phase: .build, files: files)
        let mainStep = try XCTUnwrap(plan.steps.first {
            argument(after: "-p", in: $0.arguments) == "main"
        })
        let configuration = try XCTUnwrap(mainStep.generatedFiles.values.first)

        XCTAssertTrue(
            configuration.contains("packagefile example.com/forge/greet="),
            "the main package should be able to resolve its own module's package"
        )
        XCTAssertTrue(configuration.contains("packagefile fmt="))
    }

    /// A library has no entry point, and reporting that as an error would be
    /// wrong rather than strict.
    func testALibraryModuleCompilesWithoutLinking() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "greet.go": "package greet\n\nfunc Say() string { return \"hi\" }\n",
        ]

        let plan = try planner().plan(phase: .build, files: files)

        XCTAssertEqual(plan.steps.map(\.tool), [.compile])
        XCTAssertTrue(plan.products.isEmpty)
    }

    // MARK: - Refusals

    func testAnImportNothingProvidesIsRefusedBeforeAnyToolRuns() {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\n\nimport \"github.com/nope/nope\"\n\nfunc main() {}\n",
        ]

        XCTAssertThrowsError(try planner().plan(phase: .build, files: files)) { error in
            guard case let .unresolvedImport(path, importedBy) = error as? GoPackageGraph.GraphError else {
                return XCTFail("expected an unresolved import, got \(error)")
            }
            XCTAssertEqual(path, "github.com/nope/nope")
            XCTAssertEqual(importedBy, "example.com/forge")
            XCTAssertTrue(
                GoPlanFailureReader.describe(.unresolvedImport(path, importedBy: importedBy))
                    .contains("bundled standard library")
            )
        }
    }

    func testAnImportCycleIsReportedRatherThanBrokenArbitrarily() {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "a/a.go": "package a\n\nimport \"example.com/forge/b\"\n\nfunc A() { b.B() }\n",
            "b/b.go": "package b\n\nimport \"example.com/forge/a\"\n\nfunc B() { a.A() }\n",
        ]

        XCTAssertThrowsError(try planner().plan(phase: .build, files: files)) { error in
            guard case .importCycle = error as? GoPackageGraph.GraphError else {
                return XCTFail("expected an import cycle, got \(error)")
            }
        }
    }

    func testTwoPackageClausesInOneDirectoryAreRefused() {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\n\nfunc main() {}\n",
            "other.go": "package other\n\nfunc Other() {}\n",
        ]

        XCTAssertThrowsError(try planner().plan(phase: .build, files: files)) { error in
            guard case let .conflictingPackageNames(_, names) = error as? GoPackageGraph.GraphError else {
                return XCTFail("expected conflicting package names, got \(error)")
            }
            XCTAssertEqual(names, ["main", "other"])
        }
    }

    // MARK: - Vet and format

    func testVetCompilesFirstAndThenChecksEachPackage() throws {
        let plan = try planner().plan(phase: .vet, files: helloWorld)

        XCTAssertEqual(plan.steps.map(\.tool), [.compile, .vet])
        let vetStep = try XCTUnwrap(plan.steps.last)
        let text = try XCTUnwrap(vetStep.generatedFiles.values.first)
        let configuration = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        )

        XCTAssertEqual(configuration["ImportPath"] as? String, "example.com/forge")
        XCTAssertEqual(configuration["Compiler"] as? String, "gc")
        // vet resolves every import through its own map, and an empty one
        // fails to import anything at all — including fmt.
        let importMap = try XCTUnwrap(configuration["ImportMap"] as? [String: String])
        XCTAssertEqual(importMap["fmt"], "fmt")
        let packageFile = try XCTUnwrap(configuration["PackageFile"] as? [String: String])
        XCTAssertEqual(packageFile["fmt"], GoGuestPath.standardLibraryArchive(for: "fmt"))
    }

    func testFormatIsOnePassOverTheStagedModule() throws {
        let plan = try planner().plan(phase: .format, files: helloWorld)

        XCTAssertEqual(plan.steps.map(\.tool), [.format])
        XCTAssertEqual(plan.steps.first?.arguments, ["gofmt", "-l", "-w", GoGuestPath.work])
    }

    // MARK: - Helpers

    private func argument(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// The guest-path mapping, which nothing else can check for you: a collision
/// here compiles one package over another and the build still "succeeds".
final class GoGuestPathTests: XCTestCase {
    func testFlatteningIsInjective() {
        let paths = [
            "example.com/forge",
            "example.com/forge_test",
            "example.com/forge/test",
            "example.com/forge-test",
            "example.com/forge/test_x",
            "example.com/forge_test/x",
            "a_b", "a-b", "a/b", "a.b",
        ]
        let flattened = paths.map(GoGuestPath.flattened)

        XCTAssertEqual(
            Set(flattened).count, paths.count,
            "two import paths collapsed onto one archive name: \(flattened)"
        )
    }

    func testFlatteningProducesNoPathSeparators() {
        for path in ["example.com/a/b", "a/b/c/d"] {
            XCTAssertFalse(
                GoGuestPath.flattened(path).contains("/"),
                "a flattened name must never need a directory to exist"
            )
        }
    }
}
