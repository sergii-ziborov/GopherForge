import Foundation

/// What the learner has actually done, gathered from evidence the app already
/// keeps rather than from a separate score.
///
/// Every field traces to something that happened: an attempt in the progress
/// store, a finished drill, a build record. Nothing here is awarded for opening
/// a screen.
struct LearnerStats: Equatable, Sendable {
    var lessonsPassed = 0
    /// Lessons passed on the first compile — a different signal from passing
    /// after eleven tries, and worth its own recognition.
    var lessonsPassedFirstTry = 0
    var conceptsMastered = 0
    var drillsCompleted = 0
    var drillsPerfect = 0
    var quizzesPassed = 0
    var quizzesPerfect = 0
    var programsRun = 0
    var testsPassed = 0
    /// Concepts that were mistaken at least once and later mastered. The
    /// interesting number: not what you knew, what you fixed.
    var conceptsRepaired = 0
    var distinctActiveDays = 0

    static let empty = LearnerStats()
}

/// How far up a badge somebody has climbed.
///
/// Four ranks rather than a number, because "silver" is something you can hold
/// in your head between sessions and "level 7" is not.
enum AchievementRank: String, CaseIterable, Comparable, Sendable {
    case bronze
    case silver
    case gold
    case platinum

    var title: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        }
    }

    var symbol: String {
        switch self {
        case .bronze: "medal"
        case .silver: "medal.fill"
        case .gold: "trophy"
        case .platinum: "crown.fill"
        }
    }

    private var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
}

/// One rung of a badge.
struct AchievementLevel: Equatable, Sendable {
    let rank: AchievementRank
    /// What the measured number has to reach.
    let target: Int
    /// The name of this rung, which is what a learner actually earns.
    let title: String
}

/// One badge: a single fact, measured, with rungs to climb.
///
/// Levels rather than one bar, because the honest shape of learning is that
/// running ten programs and running two hundred are different achievements —
/// and a badge that is finished after the tenth stops saying anything on the
/// eleventh.
struct Achievement: Identifiable, Equatable, Sendable {
    /// The bar an achievement measures against. A case per measurable fact,
    /// rather than a closure, so the whole set is inspectable and testable as
    /// data — and so nothing can be awarded by code nobody can read.
    enum Measure: String, Equatable, Sendable, CaseIterable {
        case lessonsPassed
        case lessonsPassedFirstTry
        case conceptsMastered
        case drillsCompleted
        case drillsPerfect
        case quizzesPassed
        case quizzesPerfect
        case programsRun
        case testsPassed
        case conceptsRepaired
        case activeDays

        func progress(in stats: LearnerStats) -> Int {
            switch self {
            case .lessonsPassed: stats.lessonsPassed
            case .lessonsPassedFirstTry: stats.lessonsPassedFirstTry
            case .conceptsMastered: stats.conceptsMastered
            case .drillsCompleted: stats.drillsCompleted
            case .drillsPerfect: stats.drillsPerfect
            case .quizzesPassed: stats.quizzesPassed
            case .quizzesPerfect: stats.quizzesPerfect
            case .programsRun: stats.programsRun
            case .testsPassed: stats.testsPassed
            case .conceptsRepaired: stats.conceptsRepaired
            case .activeDays: stats.distinctActiveDays
            }
        }
    }

    let id: String
    let title: String
    /// What earns it, in the words a learner would use.
    let detail: String
    let symbol: String
    let measure: Measure
    /// Ascending by target. The catalogue is checked for this, because a level
    /// list out of order would silently award the wrong rank.
    let levels: [AchievementLevel]

    var progressUnit: String {
        switch measure {
        case .lessonsPassed, .lessonsPassedFirstTry: "lessons"
        case .conceptsMastered, .conceptsRepaired: "concepts"
        case .drillsCompleted, .drillsPerfect: "drills"
        case .quizzesPassed, .quizzesPerfect: "quizzes"
        case .programsRun: "programs"
        case .testsPassed: "tests"
        case .activeDays: "days"
        }
    }

    func progress(in stats: LearnerStats) -> Int {
        measure.progress(in: stats)
    }

    /// The highest rung reached, or nil before the first one.
    func currentLevel(for stats: LearnerStats) -> AchievementLevel? {
        let done = progress(in: stats)
        return levels.last { done >= $0.target }
    }

    /// The rung being climbed, or nil once every one is behind.
    func nextLevel(for stats: LearnerStats) -> AchievementLevel? {
        let done = progress(in: stats)
        return levels.first { done < $0.target }
    }

    /// Any level at all counts as unlocked: the badge is on the shelf, even if
    /// it is not yet gold.
    func isUnlocked(by stats: LearnerStats) -> Bool {
        currentLevel(for: stats) != nil
    }

    func isComplete(for stats: LearnerStats) -> Bool {
        nextLevel(for: stats) == nil
    }

    func earnedLevelCount(for stats: LearnerStats) -> Int {
        let done = progress(in: stats)
        return levels.count { done >= $0.target }
    }

    /// How far along the rung currently being climbed, measured from the one
    /// below it — so a bar that just reset to bronze does not read as almost
    /// finished with silver.
    func fraction(of stats: LearnerStats) -> Double {
        guard let next = nextLevel(for: stats) else { return 1 }
        let floorValue = currentLevel(for: stats)?.target ?? 0
        let span = next.target - floorValue
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(progress(in: stats) - floorValue) / Double(span)))
    }

    func progressLabel(for stats: LearnerStats) -> String {
        guard let next = nextLevel(for: stats) else {
            return "\(progress(in: stats))"
        }
        return "\(progress(in: stats)) / \(next.target)"
    }
}
