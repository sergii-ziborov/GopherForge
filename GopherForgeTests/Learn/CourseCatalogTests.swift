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

    /// A lesson with a hidden test nobody has ever passed is a dead end, and
    /// the only cheap way to know is to keep a complete answer beside it.
    func testEveryCompileLessonHasAVerifiedSolution() {
        for lesson in GoCourseCatalog.lessons where lesson.requiresCompiler {
            XCTAssertNotNil(
                lesson.verifiedSolution,
                "\(lesson.id) has no entry in LessonSolutionCatalog"
            )
        }
    }

    /// And nothing in the catalog should answer a lesson that no longer exists.
    func testNoSolutionIsOrphaned() {
        let lessonIDs = Set(GoCourseCatalog.lessons.map(\.id))
        let orphans = LessonSolutionCatalog.coveredLessonIDs.subtracting(lessonIDs)
        XCTAssertTrue(orphans.isEmpty, "solutions for lessons that do not exist: \(orphans.sorted())")
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

    /// A lab scenario teaches a concept by showing it run. If no lesson also
    /// teaches it, review can never schedule practice for what the lab just
    /// demonstrated, which is how a concept quietly becomes unreachable.
    func testEveryLabConceptIsAlsoTaughtByALesson() {
        let labTags = Set(ConcurrencyLabScenario.all.flatMap(\.conceptTags))
        let untaught = labTags.subtracting(GoCourseCatalog.taughtConcepts)
        XCTAssertTrue(untaught.isEmpty, "lab concepts with no lesson: \(untaught.sorted())")
    }
}
