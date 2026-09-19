import XCTest
@testable import GopherForge

final class GoEnginePlannerMoreTests: XCTestCase {
    private let standardLibrary: Set<String> = [
        "fmt", "os", "strings", "testing", "testing/internal/testdeps", "unsafe",
    ]

    private func planner(modulePath: String = "example.com/forge") -> GoBuildPlanner {
        GoBuildPlanner(
            modulePath: modulePath,
            languageVersion: "go1.24",
            standardLibrary: standardLibrary,
            toolchainTag: "planner-more"
        )
    }

    func testSetupProducesAnEmptyPlan() throws {
        let plan = try planner().plan(
            phase: .setup,
            files: ["main.go": "package main\nfunc main() {}\n"]
        )
        XCTAssertTrue(plan.isEmpty)
        XCTAssertTrue(plan.products.isEmpty)
    }

    func testNoGoFilesFailBeforeAToolIsNamed() {
        XCTAssertThrowsError(
            try planner().plan(phase: .build, files: ["go.mod": "module example.com/forge\n"])
        ) { error in
            XCTAssertEqual(error as? GoPackageGraph.GraphError, .noGoFiles)
            XCTAssertTrue(GoPlanFailureReader.describe(.noGoFiles).contains("no .go files"))
        }
    }

    func testAVendoredDependencyIsCompiledUnderItsPublishedPath() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\nimport \"github.com/google/uuid\"\nfunc main() {}\n",
            "vendor/github.com/google/uuid/uuid.go": "package uuid\n",
        ]
        let plan = try planner().plan(phase: .build, files: files)
        let compiled = plan.steps.filter { $0.tool == .compile }.compactMap { step in
            step.arguments.dropFirst().first { $0.contains("github.com") || $0 == "main" }
        }
        XCTAssertTrue(
            plan.steps.contains { step in
                (step.arguments.contains { $0 == "github.com/google/uuid" }
                    || step.label.contains("github.com/google/uuid"))
                    && step.tool == .compile
            },
            "\(plan.steps.map(\.label))"
        )
        XCTAssertTrue(compiled.contains("main") || plan.steps.contains { $0.label.contains("main") })
    }

    func testCompileStepsCarryACacheKeyWhenSourcesAreKnown() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\nfunc main() {}\n",
        ]
        let plan = try planner().plan(phase: .run, files: files)
        let compile = try XCTUnwrap(plan.steps.first { $0.tool == .compile })
        XCTAssertNotNil(compile.cacheKey)
        XCTAssertEqual(compile.cacheKey?.count, 64)
        XCTAssertNotNil(compile.outputPath)
    }

    func testTwoBuildsOfTheSameSourcesShareACacheKey() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "main.go": "package main\nfunc main() {}\n",
        ]
        let first = try planner().plan(phase: .build, files: files)
        let second = try planner().plan(phase: .build, files: files)
        XCTAssertEqual(
            first.steps.compactMap(\.cacheKey),
            second.steps.compactMap(\.cacheKey)
        )
    }

    func testEditingOnePackageChangesOnlyThatKey() throws {
        func files(_ greet: String) -> [String: String] {
            [
                "go.mod": "module example.com/forge\n\ngo 1.24\n",
                "main.go": "package main\nimport \"example.com/forge/greet\"\nfunc main() { greet.Hi() }\n",
                "greet/greet.go": greet,
            ]
        }
        let first = try planner().plan(
            phase: .build,
            files: files("package greet\nfunc Hi() {}\n")
        )
        let second = try planner().plan(
            phase: .build,
            files: files("package greet\nfunc Hi() { _ = 1 }\n")
        )
        let firstKeys = Dictionary(
            uniqueKeysWithValues: first.steps.filter { $0.tool == .compile }.map { ($0.label, $0.cacheKey) }
        )
        let secondKeys = Dictionary(
            uniqueKeysWithValues: second.steps.filter { $0.tool == .compile }.map { ($0.label, $0.cacheKey) }
        )
        XCTAssertNotEqual(
            firstKeys["compile example.com/forge/greet"],
            secondKeys["compile example.com/forge/greet"]
        )
        XCTAssertNotEqual(
            firstKeys["compile example.com/forge"],
            secondKeys["compile example.com/forge"]
        )
    }

    func testFormatStillWorksWhenTheProjectWouldNotBuild() throws {
        let files = [
            "go.mod": "module example.com/forge\n",
            "main.go": "package main\nimport \"not.installed/dep\"\n",
        ]
        let plan = try planner().plan(phase: .format, files: files)
        XCTAssertEqual(plan.steps.map(\.tool), [.format])
        XCTAssertTrue(plan.products.isEmpty)
    }

    func testALibraryHasNoProductOnBuild() throws {
        let plan = try planner().plan(
            phase: .build,
            files: [
                "go.mod": "module example.com/lib\n",
                "lib.go": "package lib\nfunc F() {}\n",
            ]
        )
        XCTAssertTrue(plan.products.isEmpty)
        XCTAssertEqual(plan.steps.map(\.tool), [.compile])
    }

    func testTwoMainsWithoutATargetAreAmbiguous() {
        XCTAssertThrowsError(
            try planner().plan(
                phase: .run,
                files: [
                    "go.mod": "module example.com/forge\n\ngo 1.24\n",
                    "cmd/one/main.go": "package main\nfunc main() {}\n",
                    "cmd/two/main.go": "package main\nfunc main() {}\n",
                ]
            )
        ) { error in
            guard case let .ambiguousMainPackages(paths) = error as? GoPackageGraph.GraphError else {
                return XCTFail("\(error)")
            }
            XCTAssertTrue(paths.contains("cmd/one"))
            XCTAssertTrue(paths.contains("cmd/two"))
            XCTAssertTrue(GoPlanFailureReader.describe(.ambiguousMainPackages(paths)).contains("main.go"))
        }
    }

    func testAChosenMainIsTheOnlyProduct() throws {
        let plan = try planner().plan(
            phase: .run,
            files: [
                "go.mod": "module example.com/forge\n\ngo 1.24\n",
                "cmd/one/main.go": "package main\nfunc main() {}\n",
                "cmd/two/main.go": "package main\nfunc main() {}\n",
            ],
            packagePattern: "./cmd/one"
        )
        XCTAssertEqual(plan.products.map(\.importPath), ["example.com/forge/cmd/one"])
        XCTAssertEqual(plan.products.first?.guestPath, GoGuestPath.runProgram)
        XCTAssertTrue(plan.steps.contains { $0.tool == .link })
    }

    func testAnUnknownImportIsAReadableRefusal() {
        XCTAssertThrowsError(
            try planner().plan(
                phase: .build,
                files: [
                    "go.mod": "module example.com/forge\n",
                    "main.go": "package main\nimport \"github.com/missing/mod\"\nfunc main() {}\n",
                ]
            )
        ) { error in
            guard case let .unresolvedImport(path, importedBy) =
                    error as? GoPackageGraph.GraphError else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(path, "github.com/missing/mod")
            XCTAssertEqual(importedBy, "example.com/forge")
            let text = GoPlanFailureReader.describe(.unresolvedImport(path, importedBy: importedBy))
            XCTAssertTrue(text.contains("offline") || text.contains("bundled standard library"))
        }
    }
}
