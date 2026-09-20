import XCTest
@testable import GopherForge

final class NewProjectDraftTests: XCTestCase {
    func testStarterPackagesAreNotedOnGoModAndLeftUnvendored() {
        let template = ProjectTemplate.commandLineTool
        let draft = NewProjectDraft(
            project: template.project(named: "Parser"),
            folder: "CLI",
            tags: ["wip"],
            wantedPackages: ["rsc.io/quote", "golang.org/x/sync"]
        )

        let annotated = draft.annotatingStarterPackages()
        let goMod = annotated.project.files["go.mod"] ?? ""

        XCTAssertTrue(goMod.contains("module parser"), goMod)
        XCTAssertTrue(goMod.contains("rsc.io/quote"), goMod)
        XCTAssertTrue(goMod.contains("golang.org/x/sync"), goMod)
        XCTAssertFalse(
            goMod.contains("require rsc.io/quote"),
            "a comment is not a requirement: the template must still build offline"
        )
        XCTAssertEqual(annotated.project.goFileCount, draft.project.goFileCount)
        XCTAssertEqual(annotated.folder, "CLI")
        XCTAssertEqual(annotated.tags, ["wip"])
    }

    func testNoPackagesLeavesTheModuleAlone() {
        let project = ProjectTemplate.commandLineTool.project(named: "plain")
        let original = project.files["go.mod"]
        let draft = NewProjectDraft(
            project: project,
            folder: "",
            tags: [],
            wantedPackages: []
        )
        XCTAssertEqual(draft.annotatingStarterPackages().project.files["go.mod"], original)
    }

    func testAnnotatingTwiceDoesNotDuplicateTheNote() {
        let draft = NewProjectDraft(
            project: ProjectTemplate.commandLineTool.project(named: "once"),
            folder: "",
            tags: [],
            wantedPackages: ["rsc.io/quote"]
        )
        let once = draft.annotatingStarterPackages()
        let twice = once.annotatingStarterPackages()
        let count = twice.project.files["go.mod"]?.components(separatedBy: "rsc.io/quote").count ?? 0
        XCTAssertEqual(count, 2, "the path appears once after the split, plus the empty tail")
    }

    func testEveryTemplateSurvivesStarterPackageNotes() {
        for template in ProjectTemplate.all {
            let draft = NewProjectDraft(
                project: template.project(named: template.title),
                folder: "Box",
                tags: ["tag"],
                wantedPackages: ["example.com/mod"]
            )
            let goMod = draft.annotatingStarterPackages().project.files["go.mod"] ?? ""
            XCTAssertTrue(goMod.contains("example.com/mod"), template.id)
            XCTAssertTrue(goMod.hasPrefix("module "), template.id)
        }
    }
}
