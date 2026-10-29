import XCTest
@testable import GopherForge

final class IdiomAnalyzerTests: XCTestCase {
    private let analyzer = IdiomAnalyzer()

    func testFlagsContextThatIsNotFirst() {
        let findings = analyzer.analyze(
            source: "func Fetch(url string, ctx context.Context) error {\n}\n",
            fileName: "main.go"
        )
        XCTAssertTrue(findings.contains { $0.conceptTag == GoConcept.contextFirstParameter })
    }

    func testAcceptsContextAsFirstParameter() {
        let findings = analyzer.analyze(
            source: "func Fetch(ctx context.Context, url string) error {\n}\n",
            fileName: "main.go"
        )
        XCTAssertFalse(findings.contains { $0.conceptTag == GoConcept.contextFirstParameter })
    }

    func testGetPrefixIsAdviceWithoutAnUnsafeRename() throws {
        let source = "func (s *Server) GetOwner() string { return s.owner }\n"
        let finding = try XCTUnwrap(analyzer.analyze(source: source, fileName: "owner.go").first)
        XCTAssertEqual(finding.ruleID, "getter-without-get-prefix")
        XCTAssertFalse(finding.isAutoRepairable)
        XCTAssertThrowsError(try IdiomRepair.apply(finding, to: source, expectedLine: source)) {
            XCTAssertEqual($0 as? IdiomRepair.RepairError, .notRepairable)
        }
    }

    func testEarlyReturnNeverOffersAConditionOnlyRewrite() throws {
        for source in [
            "func describe(err error) string {\n    if err == nil {\n        return \"success\"\n    }\n    return \"failure\"\n}",
            "func visit(err error) {\n    if err == nil {\n        success()\n    } else {\n        failure()\n    }\n}",
        ] {
            let finding = try XCTUnwrap(analyzer.analyze(source: source, fileName: "main.go").first { $0.ruleID == "early-return-over-nesting" })
            XCTAssertFalse(finding.isAutoRepairable)
            XCTAssertThrowsError(try IdiomRepair.apply(finding, to: source, expectedLine: "    if err == nil {")) {
                XCTAssertEqual($0 as? IdiomRepair.RepairError, .notRepairable)
            }
        }
    }

    func testUpperCaseErrorStringIsLowered() {
        let source = "\treturn errors.New(\"Bad path\")\n"
        let findings = analyzer.analyze(source: source, fileName: "main.go")
        guard let finding = findings.first(where: { $0.ruleID == "error-string-style" }) else {
            return XCTFail("expected an error-string finding")
        }
        let repaired = try? IdiomRepair.apply(
            finding,
            to: source,
            expectedLine: IdiomRepair.line(at: finding, in: source) ?? ""
        )
        XCTAssertTrue(repaired?.contains("\"bad path\"") ?? false)
    }

    func testCommentsAreNeverAnalyzed() {
        let findings = analyzer.analyze(
            source: "// func Fetch(url string, ctx context.Context) error\n",
            fileName: "main.go"
        )
        XCTAssertTrue(findings.isEmpty)
    }

    func testRepairRefusesWhenTheLineChanged() {
        let source = "return errors.New(\"Bad path\")\n"
        let findings = analyzer.analyze(source: source, fileName: "main.go")
        guard let finding = findings.first(where: { $0.isAutoRepairable }) else {
            return XCTFail("expected a repairable finding")
        }
        XCTAssertThrowsError(
            try IdiomRepair.apply(finding, to: source, expectedLine: "something else")
        ) { error in
            XCTAssertEqual(error as? IdiomRepair.RepairError, .sourceChanged)
        }
    }
    func testRepairRejectsAnotherDocumentAndEditsOutsideItsLine() throws {
        let original = "package main\nreturn errors.New(\"Bad path\")\n"
        let finding = try XCTUnwrap(analyzer.analyze(source: original, fileName: "b.go").first)
        for changed in ["package other\nreturn errors.New(\"Bad path\")\n", "package main\nreturn errors.New(\"Different\")\n"] {
            XCTAssertThrowsError(try IdiomRepair.apply(
                finding, to: changed, expectedLine: IdiomRepair.line(at: finding, in: changed) ?? ""
            )) { XCTAssertEqual($0 as? IdiomRepair.RepairError, .sourceChanged) }
        }
    }
}

@MainActor
final class WorkspaceIdiomRepairTests: XCTestCase {
    private let a = "package main\n\nimport \"fmt\"\n\nfunc main() {\n    fmt.Println(\"A stays unchanged\")\n}\n"
    private let b = "package main\n\nimport \"errors\"\n\nfunc fail() error {\n    return errors.New(\"Failure\")\n}\n"

    private func opened() async -> (WorkspaceModel, ProjectLibrary, URL) {
        let url = FileManager.default.temporaryDirectory.appending(path: "idiom-\(UUID()).json")
        let library = ProjectLibrary(storageURL: url)
        let workspace = WorkspaceModel(library: library)
        workspace.open(GopherForgeProject(name: "Two files", files: ["a.go": a, "b.go": b], entryFile: "a.go", provenance: nil))
        await workspace.libraryUpdated()
        return (workspace, library, url)
    }

    private func finding(in workspace: WorkspaceModel) async throws -> IdiomFinding {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let found = workspace.idiomFindings.first(where: { $0.fileName == "b.go" && $0.isAutoRepairable }) { return found }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw NSError(domain: "Missing idiom finding", code: 1)
    }

    func testRepairAddressesTheAnalyzedFileWhileAnotherFileIsOpen() async throws {
        let (workspace, library, url) = await opened()
        defer { try? FileManager.default.removeItem(at: url) }
        let found = try await finding(in: workspace)
        XCTAssertEqual(found.line, 6)
        XCTAssertTrue(workspace.applyIdiom(found))
        XCTAssertEqual(workspace.editorText, a)
        XCTAssertEqual(workspace.project?.files["a.go"], a)
        XCTAssertEqual(workspace.project?.files["b.go"], b.replacingOccurrences(of: "Failure", with: "failure"))
        XCTAssertFalse(workspace.applyIdiom(found), "a finding cannot be applied twice")
        await workspace.flush()
        let stored = try await library.items()
        XCTAssertEqual(stored.first?.project.files["a.go"], a)
        XCTAssertEqual(stored.first?.project.files["b.go"], workspace.project?.files["b.go"])
    }

    func testRepairRejectsRenameDeletionEditsAndSwitchingProjects() async throws {
        for change in 0..<4 {
            let (workspace, _, url) = await opened()
            defer { try? FileManager.default.removeItem(at: url) }
            let found = try await finding(in: workspace)
            switch change {
            case 0: try workspace.renameFile(at: "b.go", to: "renamed.go")
            case 1: try workspace.deleteFile(at: "b.go")
            case 2:
                workspace.select(file: "b.go")
                workspace.updateEditorText(b + "// changed\n")
            default: workspace.open(ProjectTemplate.commandLineTool.project(named: "Other"))
            }
            let before = workspace.project?.files
            XCTAssertFalse(workspace.applyIdiom(found))
            XCTAssertEqual(workspace.project?.files, before)
            await workspace.flush()
        }
    }
}
