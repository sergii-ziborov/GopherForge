import XCTest
@testable import GopherForge

/// Planning a test run, asserted as data.
///
/// `go test` builds a different shape from `go build`: the package under test
/// is recompiled with its test files folded in, an external test package may
/// sit beside it, and the entry point is generated. All three are visible in
/// the plan, which is what makes them checkable without a compiler.
final class GoTestPlannerTests: XCTestCase {
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

    func testATestedPackageIsRecompiledWithItsTestFiles() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "mathx.go": "package mathx\n\nfunc Double(n int) int { return n * 2 }\n",
            "mathx_test.go": """
            package mathx

            import "testing"

            func TestDouble(t *testing.T) {}
            """,
        ]

        let plan = try planner().plan(phase: .test, files: files)
        let withTests = try XCTUnwrap(plan.steps.first { $0.label.contains("[test]") })

        XCTAssertTrue(withTests.arguments.contains(GoGuestPath.source("mathx.go")))
        XCTAssertTrue(
            withTests.arguments.contains(GoGuestPath.source("mathx_test.go")),
            "the test files belong in the package, which is how a test reaches unexported names"
        )
        XCTAssertEqual(plan.products.count, 1)
        XCTAssertEqual(plan.products.first?.importPath, "example.com/forge")
    }

    func testAnExternalTestPackageIsCompiledSeparately() throws {
        let files = [
            "go.mod": "module example.com/forge\n\ngo 1.24\n",
            "mathx.go": "package mathx\n\nfunc Double(n int) int { return n * 2 }\n",
            "mathx_ext_test.go": """
            package mathx_test

            import (
            \t"testing"

            \t"example.com/forge"
            )

            func TestDoubleFromOutside(t *testing.T) { _ = mathx.Double(1) }
            """,
        ]

        let plan = try planner().plan(phase: .test, files: files)
        let compiledPaths = plan.steps.compactMap { argument(after: "-p", in: $0.arguments) }

        XCTAssertTrue(compiledPaths.contains("example.com/forge_test"))
    }

    func testAProjectWithNoTestsLinksNothingToRun() throws {
        let plan = try planner().plan(phase: .test, files: helloWorld)

        XCTAssertTrue(plan.products.isEmpty)
        XCTAssertFalse(plan.steps.contains { $0.tool == .link })
    }


    private func argument(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}
