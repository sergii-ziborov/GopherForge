import XCTest
@testable import GopherForge

/// What is open, and what opens it.
///
/// The rule lives here rather than in a UI test because progress persists on a
/// device: a screen test can find a unit already started and quietly stop
/// checking anything. This has no state to drift.
final class PracticeCatalogTests: XCTestCase {
    private var firstUnit: CourseUnit {
        GoCourseCatalog.units[0]
    }

    /// A practice screen that is entirely locked on a fresh install is a
    /// punishment rather than something to come back to.
    func testSomethingIsOpenBeforeAnyLessonIsDone() {
        let open = PracticeCatalog.unlockedItems(completed: [])

        XCTAssertFalse(open.isEmpty, "a fresh install should have something to practise")
        XCTAssertFalse(
            open.contains { if case .quiz = $0.kind { return true } else { return false } },
            "but not the quizzes: those wait until a unit has been started"
        )
    }

    func testAQuizOpensOnceItsUnitHasBeenStarted() {
        let quiz = PracticeCatalog.items(forUnit: firstUnit.id).first {
            if case .quiz = $0.kind { return true } else { return false }
        }
        let item = try? XCTUnwrap(quiz)

        XCTAssertEqual(item?.isUnlocked(completedInUnit: 0), false)
        XCTAssertEqual(item?.isUnlocked(completedInUnit: 1), true)
    }

    /// Challenges arrive one at a time, so the first is encouraging rather than
    /// a wall of them at the end.
    func testChallengesArriveOneAtATime() {
        let challenges = PracticeCatalog.items(forUnit: firstUnit.id).filter {
            if case .challenge = $0.kind { return true } else { return false }
        }
        guard challenges.count >= 2 else { return }

        XCTAssertEqual(challenges[0].unlocksAfter, 0, "the first is the way into the unit")
        XCTAssertEqual(challenges[1].unlocksAfter, 1)
    }

    /// Only teaching lessons count towards unlocking: counting a challenge
    /// would mean practice unlocking practice.
    func testOnlyTeachingLessonsCountTowardsUnlocking() {
        let challenge = firstUnit.challenges.first
        let teaching = firstUnit.teachingLessons.first
        let challengeID = try? XCTUnwrap(challenge?.id)
        let teachingID = try? XCTUnwrap(teaching?.id)

        XCTAssertEqual(
            PracticeCatalog.completedCount(inUnit: firstUnit.id, completed: [challengeID ?? ""]),
            0
        )
        XCTAssertEqual(
            PracticeCatalog.completedCount(inUnit: firstUnit.id, completed: [teachingID ?? ""]),
            1
        )
    }

    func testEveryUnitContributesSomethingToPractise() {
        for unit in GoCourseCatalog.units {
            XCTAssertFalse(
                PracticeCatalog.items(forUnit: unit.id).isEmpty,
                "\(unit.id) offers nothing to practise"
            )
        }
    }

    func testPracticeIdentifiersAreUnique() {
        let ids = PracticeCatalog.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// A unit's teaching lessons and its challenges together are the unit, and
    /// nothing may fall between the two.
    func testEveryLessonIsEitherTaughtOrPractised() {
        for unit in GoCourseCatalog.units {
            XCTAssertEqual(
                unit.teachingLessons.count + unit.challenges.count,
                unit.lessons.count,
                "\(unit.id) has a lesson that is neither taught nor practised"
            )
        }
    }
}
