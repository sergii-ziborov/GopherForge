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

    /// Official Tour / Effective Go pages this course now teaches. A missing
    /// id here means the expansion was reverted while the README still claims
    /// it.
    func testCompileLessonsCannotBeSelfReportedAndOthersCan() {
        let compile = GoCourseCatalog.lessons.filter(\.requiresCompiler)
        let rest = GoCourseCatalog.lessons.filter { !$0.requiresCompiler }
        XCTAssertFalse(compile.isEmpty)
        XCTAssertFalse(rest.isEmpty)
        XCTAssertTrue(compile.allSatisfy { !$0.canSelfReport })
        XCTAssertTrue(rest.allSatisfy(\.canSelfReport))
    }

    func testEveryCompileLessonSharesAReuseKeyShape() {
        for lesson in GoCourseCatalog.lessons where lesson.requiresCompiler {
            let snapshot = lesson.checkSnapshot(source: "package main\nfunc main() {}\n")
            XCTAssertEqual(snapshot?.workspaceReuseKey, "lesson.\(lesson.id)", lesson.id)
        }
    }

    func testTheCourseCoversTheTourPagesItAdvertises() {
        let fromTheTour = [
            "core.named-results",
            "core.defer-stack",
            "collections.make-and-new",
            "collections.arrays",
            "collections.map-ok",
            "collections.nil-slice",
            "interfaces.stringer",
            "interfaces.empty",
            "concurrency.buffered",
            "concurrency.range-and-close",
            "concurrency.select-default",
            "concurrency.direction",
            "stdlib.http",
            "stdlib.strconv",
            "stdlib.image",
            "errors.recover",
            "concurrency.once",
            "collections.function-values",
        ]
        for id in fromTheTour {
            XCTAssertNotNil(GoCourseCatalog.lesson(id: id), "missing Tour lesson \(id)")
        }
    }
}
