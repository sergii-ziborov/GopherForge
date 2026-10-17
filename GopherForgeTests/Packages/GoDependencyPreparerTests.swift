import XCTest
@testable import GopherForge

final class GoRequirementMatchTests: XCTestCase {
    private func module(
        requirements: [GoModule.Requirement],
        replacements: [GoModule.Replacement] = []
    ) -> GoModule {
        GoModule(
            modulePath: "github.com/usememos/memos",
            goVersion: "1.27",
            toolchain: nil,
            requirements: requirements,
            replacements: replacements
        )
    }

    func testTheLongestRequirementWins() throws {
        let resolved = try GoRequirementMatch.resolve(
            importPath: "golang.org/x/sys/unix",
            module: module(requirements: [
                .init(path: "golang.org/x", version: "v0.1.0", isIndirect: true),
                .init(path: "golang.org/x/sys", version: "v0.49.0", isIndirect: true),
            ])
        ).get()

        XCTAssertEqual(resolved.path, "golang.org/x/sys")
        XCTAssertEqual(resolved.version, "v0.49.0")
    }

    func testAPackageOfThisModuleIsNotDownloaded() {
        let result = GoRequirementMatch.resolve(
            importPath: "github.com/usememos/memos/server",
            module: module(requirements: [
                .init(path: "github.com/pkg/errors", version: "v0.9.1", isIndirect: false),
            ])
        )
        XCTAssertEqual(result, .failure(.missingFromProject(importPath: "github.com/usememos/memos/server")))
    }

    func testARemoteReplaceSuppliesTheVersionThatIsFetched() throws {
        let resolved = try GoRequirementMatch.resolve(
            importPath: "github.com/pkg/errors",
            module: module(
                requirements: [
                    .init(path: "github.com/pkg/errors", version: "v0.9.1", isIndirect: false),
                ],
                replacements: [
                    .init(path: "github.com/pkg/errors", replacement: "github.com/pkg/errors v0.8.1"),
                ]
            )
        ).get()

        XCTAssertEqual(resolved, .init(path: "github.com/pkg/errors", version: "v0.8.1"))
    }

    func testALocalReplaceIsRefused() {
        let result = GoRequirementMatch.resolve(
            importPath: "github.com/pkg/errors",
            module: module(
                requirements: [
                    .init(path: "github.com/pkg/errors", version: "v0.9.1", isIndirect: false),
                ],
                replacements: [
                    .init(path: "github.com/pkg/errors", replacement: "./third_party/errors"),
                ]
            )
        )
        XCTAssertEqual(
            result,
            .failure(.localReplacement(module: "github.com/pkg/errors", path: "./third_party/errors"))
        )
    }
}

final class GoDependencyPreparerTests: XCTestCase {
    private let goMod = """
    module example.com/app

    go 1.27

    require github.com/pkg/errors v0.9.1
    """

    func testANamedModuleIsVendoredUntilTheImportResolves() async throws {
        let preparer = GoDependencyPreparer(
            planError: { files, _ in
                files.keys.contains { $0.hasPrefix("vendor/github.com/pkg/errors/") }
                    ? nil
                    : .unresolvedImport("github.com/pkg/errors", importedBy: "example.com/app")
            },
            install: { path, version, files in
                XCTAssertEqual(path, "github.com/pkg/errors")
                XCTAssertEqual(version, "v0.9.1")
                var next = files
                next["vendor/github.com/pkg/errors/errors.go"] = "package errors\n"
                return next
            }
        )

        let prepared = try await preparer.prepare(files: [
            "go.mod": goMod,
            "main.go": "package main\nimport \"github.com/pkg/errors\"\nfunc main() {}\n",
        ])

        XCTAssertEqual(prepared.installed, ["github.com/pkg/errors"])
        XCTAssertNotNil(prepared.files["vendor/github.com/pkg/errors/errors.go"])
    }

    func testAnImportTheModuleDoesNotRequireIsLeftForTheCompiler() async throws {
        let preparer = GoDependencyPreparer(
            planError: { _, _ in
                .unresolvedImport("github.com/google/uuid", importedBy: "example.com/app")
            },
            install: { _, _, _ in
                XCTFail("nothing in go.mod provides this import")
                return [:]
            }
        )

        let prepared = try await preparer.prepare(files: ["go.mod": goMod, "main.go": "package main\n"])

        XCTAssertTrue(prepared.installed.isEmpty)
        XCTAssertNil(prepared.files["vendor/github.com/google/uuid/uuid.go"])
    }

    func testAModuleThatDoesNotContainTheImportIsReportedAndSkipped() async throws {
        let preparer = GoDependencyPreparer(
            planError: { _, skipping in
                skipping.contains("github.com/pkg/errors")
                    ? nil
                    : .unresolvedImport("github.com/pkg/errors", importedBy: "example.com/app")
            },
            install: { _, _, files in
                var next = files
                next["vendor/github.com/pkg/errors/errors.go"] = "package errors\n"
                return next
            }
        )

        let prepared = try await preparer.prepare(files: ["go.mod": goMod])

        XCTAssertEqual(prepared.problems.map(\.reason), [.notLoaded])
        XCTAssertTrue(prepared.problems[0].outputLine.contains("does not contain that package"))
    }

    func testAFailedDownloadIsClassifiedAndDoesNotHideTheNextModule() async throws {
        let goMod = """
        module example.com/app

        go 1.27

        require (
        \tgithub.com/pkg/errors v0.9.1
        \tgolang.org/x/sync v0.24.0
        )
        """
        let preparer = GoDependencyPreparer(
            planError: { files, skipping in
                if !skipping.contains("github.com/pkg/errors"),
                   !files.keys.contains(where: { $0.hasPrefix("vendor/github.com/pkg/errors/") }) {
                    return .unresolvedImport("github.com/pkg/errors", importedBy: "example.com/app")
                }
                if !files.keys.contains(where: { $0.hasPrefix("vendor/golang.org/x/sync/") }) {
                    return .unresolvedImport("golang.org/x/sync/semaphore", importedBy: "example.com/app")
                }
                return nil
            },
            install: { path, _, files in
                if path == "github.com/pkg/errors" {
                    throw GoModuleProxyClient.ProxyError.tooLarge(40_000_000)
                }
                var next = files
                next["vendor/\(path)/sync.go"] = "package sync\n"
                return next
            }
        )

        let prepared = try await preparer.prepare(files: ["go.mod": goMod, "main.go": "package main\n"])

        XCTAssertEqual(prepared.problems.map(\.reason), [.noSpace])
        XCTAssertTrue(prepared.problems[0].outputLine.contains("isn't enough space"))
        XCTAssertEqual(prepared.installed, ["golang.org/x/sync"])
        XCTAssertEqual(
            GoDependencyPreparer.reason(for: GoPackageInstaller.InstallError.invalidModulePath("x@nope")),
            .unsupportedVersion
        )
        XCTAssertEqual(
            GoDependencyPreparer.reason(for: GoModuleProxyClient.ProxyError.notFound("x")),
            .notLoaded
        )
    }
}
