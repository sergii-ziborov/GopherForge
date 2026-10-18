import XCTest
@testable import GopherForge

final class LessonGuideTests: XCTestCase {
    func testEveryLessonAndChallengeHasAnAuthoredGuide() {
        let expected = Set(GoCourseCatalog.lessons.filter { !$0.isReading }.map(\.id))
        let actual = LessonGuideCatalog.all.map(\.id)
        XCTAssertEqual(Set(actual), expected)
        XCTAssertEqual(actual.count, expected.count, "No duplicated or orphaned diagrams")
        for guide in LessonGuideCatalog.all {
            XCTAssertEqual(guide.nodes.count, 3, guide.id)
            XCTAssertTrue(guide.nodes.allSatisfy { !$0.label.isEmpty && !$0.code.isEmpty && !$0.detail.isEmpty }, guide.id)
            XCTAssertGreaterThan(guide.practical.count, 100, guide.id)
            XCTAssertGreaterThan(guide.watchOut.count, 50, guide.id)
            XCTAssertEqual(guide.reference.scheme, "https", guide.id)
            XCTAssertTrue(["go.dev", "pkg.go.dev"].contains(guide.reference.host ?? ""), guide.id)
        }
    }

    func testFencedCodeKeepsBlankLinesAndIndentation() {
        let text = "A paragraph with `inline`.\n\n```go\nfunc example() {\n\n\tprintln(1)\n}\n```\n\nAfter."
        XCTAssertEqual(LearningText.blocks(in: text), [
            .paragraph("A paragraph with `inline`."),
            .code("func example() {\n\n\tprintln(1)\n}"),
            .paragraph("After."),
        ])
    }

    @MainActor
    func testEmbeddedEditorGrowsWithAllSourceLines() {
        let short = SyntaxCodeEditor.embeddedHeight(for: "package main", fontSize: 13)
        let long = SyntaxCodeEditor.embeddedHeight(for: Array(repeating: "// line", count: 80).joined(separator: "\n"), fontSize: 13)
        XCTAssertGreaterThan(long, short * 5, "The lesson must show all lines, rather than nesting vertical scrolling")
    }
}
