import XCTest
@testable import GopherForge

final class ProjectCompatibilityMoreTests: XCTestCase {
    private func project(_ files: [String: String], name: String = "Forge") -> GopherForgeProject {
        GopherForgeProject(name: name, files: files, entryFile: "main.go", provenance: .template())
    }

    func testMissingVendorOnARequirementAsksForInspect() {
        let report = ProjectCompatibilityReport.scan(project([
            "go.mod": "module m\n\ngo 1.24\n\nrequire github.com/x/y v1.0.0\n",
            "main.go": "package main\nfunc main() {}\n",
        ]))
        XCTAssertEqual(report.status, .inspect)
        XCTAssertEqual(report.requirements, 1)
        XCTAssertTrue(report.notes.contains { $0.contains("vendor") })
    }

    func testAVendoredRequirementIsReady() {
        let report = ProjectCompatibilityReport.scan(project([
            "go.mod": "module m\n\ngo 1.24\n\nrequire github.com/x/y v1.0.0\n",
            "main.go": "package main\nfunc main() {}\n",
            "vendor/github.com/x/y/y.go": "package y\n",
        ]))
        XCTAssertEqual(report.status, .ready)
        XCTAssertTrue(report.notes.isEmpty)
    }

    func testALibraryWithoutMainIsInspected() {
        let report = ProjectCompatibilityReport.scan(project([
            "go.mod": "module m\n\ngo 1.24\n",
            "lib.go": "package lib\nfunc F() {}\n",
        ]))
        XCTAssertEqual(report.status, .inspect)
        XCTAssertTrue(report.notes.contains { $0.contains("main package") })
    }

    func testAWorkspaceFileIsNoted() {
        let report = ProjectCompatibilityReport.scan(project([
            "go.mod": "module m\n\ngo 1.24\n",
            "go.work": "go 1.24\n",
            "main.go": "package main\nfunc main() {}\n",
        ]))
        XCTAssertEqual(report.status, .inspect)
        XCTAssertTrue(report.notes.contains { $0.contains("Workspace") })
    }

    func testAnOversizedOwnFileIsNoted() {
        let long = (0...SourceFileLimit.maximumLines).map { "// \($0)" }.joined(separator: "\n")
        let report = ProjectCompatibilityReport.scan(project([
            "go.mod": "module m\n\ngo 1.24\n",
            "main.go": "package main\nfunc main() {}\n",
            "big.go": long,
        ]))
        XCTAssertTrue(report.notes.contains { $0.contains("big.go") })
    }
}
