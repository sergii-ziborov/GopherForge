import XCTest
@testable import GopherForge

/// Badges, and the evidence they are made of.
///
/// The whole design is that a badge is a fact about work done, so these tests
/// hand the builder a history and check the number rather than exercising a UI.
final class AchievementTests: XCTestCase {
    private let day = 86_400.0
    private lazy var start = Date(timeIntervalSince1970: 1_700_000_000)

    private func attempt(
        _ lesson: String,
        succeeded: Bool,
        compiles: Int = 2,
        mistakes: [String] = [],
        dayOffset: Double = 0
    ) -> LessonAttempt {
        LessonAttempt(
            lessonID: lesson,
            succeeded: succeeded,
            attemptedAt: start.addingTimeInterval(dayOffset * day),
            mistakeTags: mistakes,
            compileAttempts: compiles
        )
    }

    private func mastery(_ tag: String, successes: Int, mistakes: Int) -> ConceptMastery {
        ConceptMastery(
            conceptTag: tag,
            successes: successes,
            mistakes: mistakes,
            lastSeenAt: start,
            // Nil so the recency penalty stays out of a test about counting.
            lastMistakeAt: nil
        )
    }

    // MARK: - Stats

    func testAPassedLessonCountsOnceHoweverManyAttempts() {
        let stats = LearnerStatsBuilder.build(
            attempts: [
                attempt("l1", succeeded: false),
                attempt("l1", succeeded: true),
                attempt("l1", succeeded: true),
            ],
            mastery: [],
            drills: [],
            runs: []
        )

        XCTAssertEqual(stats.lessonsPassed, 1)
    }

    /// The first-try badge is about compiling cleanly, so a pass that took
    /// several compiles must not count towards it.
    func testFirstTryNeedsACleanCompile() {
        let stats = LearnerStatsBuilder.build(
            attempts: [
                attempt("clean", succeeded: true, compiles: 1),
                attempt("messy", succeeded: true, compiles: 6),
                attempt("flagged", succeeded: true, compiles: 1, mistakes: ["vars.unused"]),
            ],
            mastery: [],
            drills: [],
            runs: []
        )

        XCTAssertEqual(stats.lessonsPassed, 3)
        XCTAssertEqual(stats.lessonsPassedFirstTry, 1)
    }

    /// "Repaired" is the interesting number: mastered now, and wrong before.
    func testRepairedCountsOnlyConceptsThatWereOnceWrong() {
        let stats = LearnerStatsBuilder.build(
            attempts: [],
            mastery: [
                mastery("always.right", successes: 8, mistakes: 0),
                mastery("learned.it", successes: 9, mistakes: 2),
                mastery("still.shaky", successes: 1, mistakes: 4),
            ],
            drills: [],
            runs: []
        )

        XCTAssertEqual(stats.conceptsMastered, 2, "still.shaky is below the threshold")
        XCTAssertEqual(stats.conceptsRepaired, 1)
    }

    func testOnlySuccessfulRunsOfAProgramAreCounted() {
        let stats = LearnerStatsBuilder.build(
            attempts: [],
            mastery: [],
            drills: [],
            runs: [
                PracticeRun(phase: .run, succeeded: true, testsPassed: 0, ranAt: start),
                PracticeRun(phase: .run, succeeded: false, testsPassed: 0, ranAt: start),
                PracticeRun(phase: .build, succeeded: true, testsPassed: 0, ranAt: start),
                PracticeRun(phase: .test, succeeded: true, testsPassed: 7, ranAt: start),
            ]
        )

        XCTAssertEqual(stats.programsRun, 1, "a build is not a run, and a failure is not either")
        XCTAssertEqual(stats.testsPassed, 7)
    }

    func testActiveDaysCountsDaysNotEvents() {
        let stats = LearnerStatsBuilder.build(
            attempts: [
                attempt("a", succeeded: true, dayOffset: 0),
                attempt("b", succeeded: true, dayOffset: 0),
                attempt("c", succeeded: true, dayOffset: 3),
            ],
            mastery: [],
            drills: [
                MatchingDrillResult(
                    drillID: "d",
                    completedAt: start.addingTimeInterval(9 * day),
                    mistakes: 0,
                    mistakenConcepts: []
                ),
            ],
            runs: []
        )

        XCTAssertEqual(stats.distinctActiveDays, 3)
    }

    // MARK: - Catalog

    func testNothingIsEarnedFromAnEmptyHistory() {
        XCTAssertTrue(
            AchievementCatalog.unlocked(by: .empty).isEmpty,
            "a fresh install should have earned nothing"
        )
    }

    /// This is the test that catches a badge added against a statistic nothing
    /// ever sets — which is exactly how it caught the quiz ones.
    func testEveryAchievementIsReachable() {
        var everything = LearnerStats()
        everything.lessonsPassed = 999
        everything.lessonsPassedFirstTry = 999
        everything.conceptsMastered = 999
        everything.drillsCompleted = 999
        everything.drillsPerfect = 999
        everything.quizzesPassed = 999
        everything.quizzesPerfect = 999
        everything.programsRun = 999
        everything.testsPassed = 999
        everything.conceptsRepaired = 999
        everything.distinctActiveDays = 999

        XCTAssertEqual(
            AchievementCatalog.unlocked(by: everything).count,
            AchievementCatalog.all.count,
            "an achievement nothing can unlock is a bug, not a challenge"
        )
    }

    func testProgressIsClampedAndReadable() {
        var stats = LearnerStats()
        stats.programsRun = 50
        let badge = try! XCTUnwrap(AchievementCatalog.achievement(id: "ten.runs"))

        XCTAssertEqual(badge.fraction(of: stats), 1)
        XCTAssertEqual(badge.progressLabel(for: stats), "10 / 10")
    }

    /// Earned first, then closest to earned: the list should open on what you
    /// did and point at what is one step away.
    func testOrderingPutsEarnedFirstThenNearest() {
        var stats = LearnerStats()
        stats.programsRun = 1
        stats.testsPassed = 19

        let ordered = AchievementCatalog.ordered(by: stats)
        XCTAssertEqual(ordered.first?.id, "first.build", "the only earned badge leads")
        let unearned = ordered.drop { $0.isUnlocked(by: stats) }
        XCTAssertEqual(unearned.first?.id, "twenty.tests", "19 of 20 is the nearest miss")
    }

    func testAchievementIdentifiersAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
