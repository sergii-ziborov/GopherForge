import XCTest
@testable import GopherForge

/// Badges, and the rungs they are climbed by.
final class AchievementTests: XCTestCase {
    private func badge(_ id: String) throws -> Achievement {
        try XCTUnwrap(AchievementCatalog.all.first { $0.id == id })
    }

    // MARK: - The catalogue is well formed

    /// A level list out of order would award the wrong rank silently, because
    /// the current level is "the last one reached".
    func testEveryBadgeHasAscendingLevels() {
        for badge in AchievementCatalog.all {
            let targets = badge.levels.map(\.target)
            XCTAssertEqual(targets, targets.sorted(), "\(badge.id) has levels out of order")
            XCTAssertEqual(Set(targets).count, targets.count, "\(badge.id) repeats a target")
            XCTAssertFalse(badge.levels.isEmpty, "\(badge.id) has no levels")
            XCTAssertTrue(targets.allSatisfy { $0 > 0 }, "\(badge.id) has a level reachable by doing nothing")
        }
    }

    func testEveryBadgeClimbsThroughTheRanksInOrder() {
        for badge in AchievementCatalog.all {
            let ranks = badge.levels.map(\.rank)
            XCTAssertEqual(ranks, ranks.sorted(), "\(badge.id) ranks are out of order")
        }
    }

    func testBadgeIdentifiersAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// Every level name is what somebody actually earns, so a blank one is a
    /// badge with nothing to show.
    func testEveryLevelIsNamed() {
        for badge in AchievementCatalog.all {
            for level in badge.levels {
                XCTAssertFalse(level.title.isEmpty, "\(badge.id) \(level.rank) has no name")
            }
        }
    }

    // MARK: - Climbing

    func testNothingIsEarnedAtTheStart() {
        let stats = LearnerStats.empty

        XCTAssertEqual(AchievementCatalog.unlocked(by: stats).count, 0)
        XCTAssertEqual(AchievementCatalog.earnedLevelCount(by: stats), 0)
    }

    func testTheFirstRunEarnsBronzeAndOnlyBronze() throws {
        var stats = LearnerStats.empty
        stats.programsRun = 1
        let forge = try badge("programs.run")

        XCTAssertEqual(forge.currentLevel(for: stats)?.rank, .bronze)
        XCTAssertEqual(forge.nextLevel(for: stats)?.rank, .silver)
        XCTAssertEqual(forge.earnedLevelCount(for: stats), 1)
    }

    func testEveryRungIsEarnedOnceThePlatinumTargetIsMet() throws {
        var stats = LearnerStats.empty
        let forge = try badge("programs.run")
        stats.programsRun = try XCTUnwrap(forge.levels.last?.target)

        XCTAssertEqual(forge.currentLevel(for: stats)?.rank, .platinum)
        XCTAssertNil(forge.nextLevel(for: stats))
        XCTAssertEqual(forge.earnedLevelCount(for: stats), forge.levels.count)
        XCTAssertTrue(forge.isComplete(for: stats))
    }

    /// The bar measures the rung being climbed, not the whole badge. Ten runs
    /// out of a fifty-run gold level is not "20% of gold" from zero — it is the
    /// start of the climb from silver.
    func testTheBarMeasuresFromTheRungBelow() throws {
        var stats = LearnerStats.empty
        let forge = try badge("programs.run")
        stats.programsRun = 10

        XCTAssertEqual(forge.currentLevel(for: stats)?.rank, .silver)
        XCTAssertEqual(forge.fraction(of: stats), 0, accuracy: 0.001)

        stats.programsRun = 30
        XCTAssertEqual(forge.fraction(of: stats), 0.5, accuracy: 0.001)
    }

    func testAFinishedBadgeShowsAFullBar() throws {
        var stats = LearnerStats.empty
        let forge = try badge("programs.run")
        stats.programsRun = 10_000

        XCTAssertEqual(forge.fraction(of: stats), 1, accuracy: 0.001)
        XCTAssertEqual(forge.progressLabel(for: stats), "10000")
    }

    func testTheLabelCountsTowardsTheNextRung() throws {
        var stats = LearnerStats.empty
        stats.programsRun = 7

        XCTAssertEqual(try badge("programs.run").progressLabel(for: stats), "7 / 10")
    }

    // MARK: - Ordering

    /// The top of the list should be whatever is nearly earned, and a badge
    /// with nothing left to give should not sit there.
    func testFinishedBadgesSinkToTheBottom() {
        var stats = LearnerStats.empty
        stats.programsRun = 10_000

        let ordered = AchievementCatalog.ordered(by: stats)

        XCTAssertEqual(ordered.last?.id, "programs.run")
    }

    func testTheClosestBadgeComesFirst() {
        var stats = LearnerStats.empty
        // One drill away from bronze; nothing else touched.
        stats.drillsCompleted = 0
        stats.quizzesPassed = 0
        stats.programsRun = 9

        XCTAssertEqual(AchievementCatalog.ordered(by: stats).first?.id, "programs.run")
    }

    // MARK: - Every measure is reachable

    /// A measure nothing in the catalogue reads is a statistic the app collects
    /// and never uses; a badge measuring something never recorded can never be
    /// earned. Both are worth knowing about.
    func testEveryMeasureIsUsedByABadge() {
        let used = Set(AchievementCatalog.all.map(\.measure))

        for measure in Achievement.Measure.allCases {
            XCTAssertTrue(used.contains(measure), "no badge measures \(measure.rawValue)")
        }
    }

    func testEveryBadgeNamesItsUnit() {
        for badge in AchievementCatalog.all {
            XCTAssertFalse(badge.progressUnit.isEmpty, "\(badge.id) has no unit")
        }
    }
}
