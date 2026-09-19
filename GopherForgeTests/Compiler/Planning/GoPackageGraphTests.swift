import XCTest
@testable import GopherForge

/// The package graph, which decides what will compile before any tool runs.
final class GoPackageGraphTests: XCTestCase {
    private let std: Set<String> = ["fmt", "os", "testing", "unsafe"]

    private func graph(
        _ files: [String: String],
        module: String = "example.com/forge",
        includeTests: Bool = true,
        target: String? = nil,
        constraint: GoBuildConstraint? = nil
    ) throws -> GoPackageGraph {
        try GoPackageGraph.build(
            files: files,
            modulePath: module,
            standardLibrary: std,
            constraint: constraint,
            includeTestImports: includeTests,
            targetDirectory: target
        )
    }

    func testAProjectWithNoGoFilesIsRefused() {
        XCTAssertThrowsError(try graph(["go.mod": "module example.com/forge\n"])) { error in
            XCTAssertEqual(error as? GoPackageGraph.GraphError, .noGoFiles)
        }
    }

    func testAnEmptySnapshotIsRefused() {
        XCTAssertThrowsError(try graph([:])) { error in
            XCTAssertEqual(error as? GoPackageGraph.GraphError, .noGoFiles)
        }
    }

    func testConflictingPackageNamesNameTheDirectory() {
        XCTAssertThrowsError(try graph([
            "main.go": "package main\n",
            "other.go": "package other\n",
        ])) { error in
            guard case let .conflictingPackageNames(directory, names) =
                    error as? GoPackageGraph.GraphError else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(directory, "")
            XCTAssertEqual(names, ["main", "other"])
        }
    }

    func testAnImportCycleListsTheLoop() {
        XCTAssertThrowsError(try graph([
            "a/a.go": "package a\nimport \"example.com/forge/b\"\n",
            "b/b.go": "package b\nimport \"example.com/forge/a\"\n",
        ])) { error in
            guard case let .importCycle(path) = error as? GoPackageGraph.GraphError else {
                return XCTFail("\(error)")
            }
            XCTAssertTrue(path.contains("example.com/forge/a"))
            XCTAssertTrue(path.contains("example.com/forge/b"))
        }
    }

    func testAnUnknownImportNamesTheImporter() {
        XCTAssertThrowsError(try graph([
            "main.go": "package main\nimport \"github.com/missing/mod\"\nfunc main() {}\n",
        ])) { error in
            guard case let .unresolvedImport(path, importedBy) =
                    error as? GoPackageGraph.GraphError else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(path, "github.com/missing/mod")
            XCTAssertEqual(importedBy, "example.com/forge")
        }
    }

    func testAStandardLibraryImportIsAccepted() throws {
        let built = try graph([
            "main.go": "package main\nimport \"fmt\"\nfunc main() {}\n",
        ])
        XCTAssertEqual(built.packages.count, 1)
        XCTAssertEqual(built.mainPackage?.name, "main")
    }

    func testAVendoredPackageKeepsItsPublishedImportPath() throws {
        let built = try graph([
            "main.go": "package main\nimport \"github.com/google/uuid\"\nfunc main() {}\n",
            "vendor/github.com/google/uuid/uuid.go": "package uuid\n",
        ])
        let vendored = try XCTUnwrap(built.package(withImportPath: "github.com/google/uuid"))
        XCTAssertTrue(vendored.isVendored)
        XCTAssertFalse(vendored.isMain)
        XCTAssertEqual(
            GoPackageGraph.importPath(
                forDirectory: "vendor/github.com/google/uuid",
                modulePath: "example.com/forge"
            ),
            "github.com/google/uuid"
        )
    }

    func testAVendoredMainIsNotAnEntryPoint() throws {
        let built = try graph([
            "lib.go": "package lib\n",
            "vendor/example.com/cmd/main.go": "package main\nfunc main() {}\n",
        ])
        XCTAssertNil(built.mainPackage)
        XCTAssertTrue(try XCTUnwrap(built.packages.first { $0.isVendored }).isVendored)
    }

    func testDependenciesAreOrderedBeforeImporters() throws {
        let built = try graph([
            "main.go": "package main\nimport \"example.com/forge/greet\"\nfunc main() {}\n",
            "greet/greet.go": "package greet\n",
        ])
        XCTAssertEqual(built.packages.map(\.importPath), [
            "example.com/forge/greet",
            "example.com/forge",
        ])
    }

    func testATestOnlyImportIsIgnoredWhenTestsAreExcluded() throws {
        let files = [
            "main.go": "package main\nfunc main() {}\n",
            "main_test.go": "package main\nimport \"github.com/missing/testkit\"\n",
        ]
        XCTAssertThrowsError(try graph(files, includeTests: true))
        XCTAssertNoThrow(try graph(files, includeTests: false))
    }

    func testSelectingOneMainIgnoresTheOtherMainsImports() throws {
        let files = [
            "cmd/ok/main.go": "package main\nfunc main() {}\n",
            "cmd/bad/main.go": "package main\nimport \"github.com/missing/mod\"\nfunc main() {}\n",
        ]
        let built = try graph(files, target: "cmd/ok")
        XCTAssertEqual(built.packages.map(\.directory), ["cmd/ok"])
    }

    func testHasTestsAndExternalImportPath() throws {
        let built = try graph([
            "mathx/mathx.go": "package mathx\n",
            "mathx/mathx_test.go": "package mathx_test\nimport \"testing\"\nfunc TestX(t *testing.T) {}\n",
        ])
        let package = try XCTUnwrap(built.package(withImportPath: "example.com/forge/mathx"))
        XCTAssertTrue(package.hasTests)
        XCTAssertEqual(package.externalTestImportPath, "example.com/forge/mathx_test")
        XCTAssertEqual(package.externalTestFiles, ["mathx/mathx_test.go"])
        XCTAssertTrue(package.goFiles.contains("mathx/mathx.go"))
    }

    func testADirectoryOfOnlyExternalTestsIsNotAPackage() throws {
        let built = try graph([
            "lib/lib.go": "package lib\n",
            "orphan/orphan_test.go": "package orphan_test\n",
        ])
        XCTAssertNil(built.package(withImportPath: "example.com/forge/orphan"))
        XCTAssertNotNil(built.package(withImportPath: "example.com/forge/lib"))
    }

    func testDirectoryAndImportPathHelpers() {
        XCTAssertEqual(GoPackageGraph.directory(of: "main.go"), "")
        XCTAssertEqual(GoPackageGraph.directory(of: "cmd/one/main.go"), "cmd/one")
        XCTAssertEqual(
            GoPackageGraph.importPath(forDirectory: "", modulePath: "playground"),
            "playground"
        )
        XCTAssertEqual(
            GoPackageGraph.importPath(forDirectory: "internal/greet", modulePath: "playground"),
            "playground/internal/greet"
        )
    }

    func testABuildTagCanDropAFileBeforeTheGraphSeesIt() throws {
        let constraint = GoBuildConstraint(environment: .wasip1(goVersion: "go1.24"))
        let built = try graph(
            [
                "main.go": "package main\nfunc main() {}\n",
                "linux.go": "//go:build linux\n\npackage main\nfunc LinuxOnly() {}\n",
            ],
            constraint: constraint
        )
        XCTAssertEqual(built.packages.first?.goFiles, ["main.go"])
    }

    func testAWasip1FileStaysInTheGraph() throws {
        let constraint = GoBuildConstraint(environment: .wasip1(goVersion: "go1.24"))
        let built = try graph(
            [
                "main.go": "package main\nfunc main() {}\n",
                "main_wasip1.go": "package main\nfunc extra() {}\n",
            ],
            constraint: constraint
        )
        XCTAssertEqual(Set(built.packages.first?.goFiles ?? []), ["main.go", "main_wasip1.go"])
    }

    func testAnAmd64FileIsDroppedOnWasm() throws {
        let constraint = GoBuildConstraint(environment: .wasip1(goVersion: "go1.24"))
        let built = try graph(
            [
                "lib.go": "package lib\n",
                "lib_amd64.go": "package lib\nfunc Native() {}\n",
            ],
            constraint: constraint
        )
        XCTAssertEqual(built.packages.first?.goFiles, ["lib.go"])
    }
}
