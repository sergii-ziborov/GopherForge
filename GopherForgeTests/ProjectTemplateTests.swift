import XCTest
@testable import GopherForge

final class ProjectTemplateTests: XCTestCase {
    func testEveryTemplateDeclaresNoDependencies() {
        for template in ProjectTemplate.all {
            let project = template.project(named: "Forge")
            let module = project.module
            XCTAssertNotNil(module, "\(template.id) has no go.mod")
            XCTAssertTrue(
                module?.requirements.isEmpty ?? false,
                "\(template.id) declares dependencies and could not build offline"
            )
        }
    }

    func testEveryTemplateHasAMainPackageAndBuildsClean() {
        for template in ProjectTemplate.all {
            let project = template.project(named: "Forge")
            let report = ProjectCompatibilityReport.scan(project)
            XCTAssertEqual(report.status, .ready, "\(template.id): \(report.notes)")
        }
    }

    func testModulePathIsNormalised() {
        XCTAssertEqual(ProjectTemplate.modulePath(for: "My First Forge!"), "my-first-forge")
        XCTAssertEqual(ProjectTemplate.modulePath(for: ""), "gopherforge-project")
    }

    func testCompatibilityReportDetectsCgo() {
        let project = GopherForgeProject(
            name: "cgo",
            files: [
                "go.mod": "module m\n\ngo 1.27\n",
                "main.go": "package main\n\nimport \"C\"\n\nfunc main() {}\n",
            ],
            entryFile: "main.go",
            provenance: nil
        )
        let report = ProjectCompatibilityReport.scan(project)
        XCTAssertTrue(report.notes.contains { $0.contains("cgo") })
    }

    func testPackageDirectoriesFollowTheFileLayout() {
        let project = GopherForgeProject(
            name: "layered",
            files: [
                "go.mod": "module m\n\ngo 1.27\n",
                "main.go": "package main\n\nfunc main() {}\n",
                "internal/build/build.go": "package build\n",
            ],
            entryFile: "main.go",
            provenance: nil
        )
        XCTAssertEqual(project.packageDirectories, [".", "internal/build"])
    }
}
