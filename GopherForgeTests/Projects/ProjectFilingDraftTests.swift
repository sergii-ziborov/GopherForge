import XCTest
@testable import GopherForge

final class ProjectFilingDraftTests: XCTestCase {
    func testADraftTrimsTheNameAndSplitsTags() {
        let item = ProjectLibraryItem(
            id: UUID(),
            project: GopherForgeProject(
                name: "parser",
                files: ["main.go": "package main\n"],
                entryFile: "main.go",
                provenance: .template()
            ),
            lastOpenedAt: Date(),
            folder: "Experiments",
            tags: ["go", "wip"],
            isFavorite: true,
            summary: "scratch"
        )
        var draft = ProjectFilingDraft(item: item)
        XCTAssertEqual(draft.trimmedName, "parser")
        XCTAssertEqual(draft.folder, "Experiments")
        XCTAssertEqual(draft.tags, ["go", "wip"])
        XCTAssertTrue(draft.isFavorite)

        draft.name = "  renamed  "
        draft.tagsText = " Go , Parser,go "
        XCTAssertEqual(draft.trimmedName, "renamed")
        XCTAssertEqual(draft.tags, ["go", "parser"])
    }
}
