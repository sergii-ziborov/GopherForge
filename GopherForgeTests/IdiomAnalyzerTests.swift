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

    func testGetPrefixIsRepairable() {
        let source = "func (s *Server) GetOwner() string {\n\treturn s.owner\n}\n"
        let findings = analyzer.analyze(source: source, fileName: "main.go")
        guard let finding = findings.first(where: { $0.ruleID == "getter-without-get-prefix" }) else {
            return XCTFail("expected a getter finding")
        }
        XCTAssertTrue(finding.isAutoRepairable)

        let line = IdiomRepair.line(at: finding, in: source)
        let repaired = try? IdiomRepair.apply(finding, to: source, expectedLine: line ?? "")
        XCTAssertTrue(repaired?.contains("func (s *Server) Owner() string") ?? false)
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
        let source = "func (s *Server) GetOwner() string {\n}\n"
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
}
