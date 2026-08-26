import XCTest
@testable import GopherForge

final class CourseCatalogTests: XCTestCase {
    func testEveryLessonHasAUniqueIdentifier() {
        let ids = GoCourseCatalog.lessons.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// A lesson that introduced a tag nobody else knows would silently never be
    /// reviewed and never be matched to a compiler error.
    func testEveryTaughtConceptExistsInTheSharedVocabulary() {
        let unknown = GoCourseCatalog.taughtConcepts.subtracting(GoConcept.all)
        XCTAssertTrue(unknown.isEmpty, "unknown concept tags: \(unknown.sorted())")
    }

    func testEveryIdiomRuleUsesAKnownConcept() {
        let unknown = Set(IdiomRuleCatalog.all.map(\.conceptTag)).subtracting(GoConcept.all)
        XCTAssertTrue(unknown.isEmpty, "unknown concept tags: \(unknown.sorted())")
    }

    func testEveryUnitHasLessonsAndATranslationNote() {
        for unit in GoCourseCatalog.units {
            XCTAssertFalse(unit.lessons.isEmpty, "\(unit.id) has no lessons")
            XCTAssertFalse(unit.translationNote.isEmpty, "\(unit.id) has no translation note")
        }
    }

    func testCompileLessonsShipAHiddenTest() {
        for lesson in GoCourseCatalog.lessons where lesson.requiresCompiler {
            guard case let .compile(starter, hiddenTest) = lesson.task else {
                return XCTFail("\(lesson.id) claims to need the compiler")
            }
            XCTAssertFalse(starter.isEmpty)
            XCTAssertTrue(hiddenTest.contains("func Test"), "\(lesson.id) has no test function")
        }
    }

    func testConcurrencyLessonsHaveALabScenario() {
        let labTags = Set(ConcurrencyLabScenario.all.flatMap(\.conceptTags))
        let unitTags = GoCourseCatalog.unit(id: "concurrency")?.conceptTags ?? []
        XCTAssertFalse(labTags.intersection(unitTags).isEmpty)
    }
}
