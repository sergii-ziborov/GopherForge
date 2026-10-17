import XCTest
@testable import GopherForge

final class GoPackageTreeTests: XCTestCase {
    private func files(_ sources: [String: String], requirements: String) -> [String: String] {
        var files = sources
        files["go.mod"] = """
        module example.com/app

        go 1.27

        require (
        \(requirements)
        )
        """
        return files
    }

    func testADependencyUsedOnlyByAPackageIsNestedUnderIt() {
        let project = files([
            "main.go": "package main\nimport \"github.com/gin-gonic/gin\"\nfunc main() {}\n",
            "vendor/github.com/gin-gonic/gin/gin.go":
                "package gin\nimport \"github.com/go-playground/validator/v10\"\n",
            "vendor/github.com/go-playground/validator/v10/validator.go": "package validator\n",
        ], requirements: """
        \tgithub.com/gin-gonic/gin v1.10.0
        \tgithub.com/go-playground/validator/v10 v10.0.0 // indirect
        """)

        let roots = GoPackageTree.nodes(in: project)
        XCTAssertEqual(roots.map(\.module.path), ["github.com/gin-gonic/gin"])
        XCTAssertEqual(roots.first?.children.map(\.module.path), ["github.com/go-playground/validator/v10"])
        XCTAssertEqual(
            GoPackageTree.rows(in: project).map(\.module.path),
            ["github.com/gin-gonic/gin"],
            "dependencies stay folded until the package is opened"
        )
        XCTAssertEqual(
            GoPackageTree.rows(in: project, expanded: ["github.com/gin-gonic/gin"]).map(\.module.path),
            ["github.com/gin-gonic/gin", "github.com/go-playground/validator/v10"]
        )
    }

    func testADependencyTheProjectImportsStaysAtTheRoot() {
        let project = files([
            "main.go": "package main\nimport \"github.com/go-playground/validator/v10\"\nfunc main() {}\n",
            "vendor/github.com/gin-gonic/gin/gin.go":
                "package gin\nimport \"github.com/go-playground/validator/v10\"\n",
            "vendor/github.com/go-playground/validator/v10/validator.go": "package validator\n",
        ], requirements: """
        \tgithub.com/gin-gonic/gin v1.10.0
        \tgithub.com/go-playground/validator/v10 v10.0.0
        """)

        XCTAssertEqual(
            Set(GoPackageTree.nodes(in: project).map(\.module.path)),
            ["github.com/gin-gonic/gin", "github.com/go-playground/validator/v10"]
        )
        XCTAssertTrue(GoPackageTree.nodes(in: project).allSatisfy(\.children.isEmpty))
    }

    func testDeletingAPackageKeepsADependencyAnotherPackageStillUses() {
        let project = files([
            "main.go": """
            package main
            import (
            \t"github.com/gin-gonic/gin"
            \t"github.com/labstack/echo/v4"
            )
            func main() {}
            """,
            "vendor/github.com/gin-gonic/gin/gin.go":
                "package gin\nimport \"github.com/go-playground/validator/v10\"\n",
            "vendor/github.com/labstack/echo/v4/echo.go":
                "package echo\nimport \"github.com/go-playground/validator/v10\"\n",
            "vendor/github.com/go-playground/validator/v10/validator.go": "package validator\n",
            "vendor/github.com/json-iterator/go/json.go": "package jsoniter\n",
        ], requirements: """
        \tgithub.com/gin-gonic/gin v1.10.0
        \tgithub.com/labstack/echo/v4 v4.0.0
        \tgithub.com/go-playground/validator/v10 v10.0.0 // indirect
        """)
        // json-iterator is only imported by gin. Add that edge.
        var withJSON = project
        withJSON["vendor/github.com/gin-gonic/gin/gin.go"] =
            "package gin\nimport (\n\t\"github.com/go-playground/validator/v10\"\n\t\"github.com/json-iterator/go\"\n)\n"
        withJSON["go.mod"] = (withJSON["go.mod"] ?? "").replacingOccurrences(
            of: "\tgithub.com/go-playground/validator/v10 v10.0.0 // indirect\n",
            with: "\tgithub.com/go-playground/validator/v10 v10.0.0 // indirect\n\tgithub.com/json-iterator/go v1.1.12 // indirect\n"
        )

        let removal = GoPackageTree.removal(of: "github.com/gin-gonic/gin", in: withJSON)
        XCTAssertEqual(removal.exclusiveDependents, ["github.com/json-iterator/go"])
        XCTAssertFalse(removal.all.contains("github.com/go-playground/validator/v10"))

        let remaining = GoPackageTree.remove(removal, from: withJSON)
        XCTAssertNil(remaining["vendor/github.com/gin-gonic/gin/gin.go"])
        XCTAssertNil(remaining["vendor/github.com/json-iterator/go/json.go"])
        XCTAssertNotNil(remaining["vendor/github.com/go-playground/validator/v10/validator.go"])
        XCTAssertNotNil(remaining["vendor/github.com/labstack/echo/v4/echo.go"])
    }
}
