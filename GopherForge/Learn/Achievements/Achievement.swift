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
    var programsRun = 0
    var testsPassed = 0
    /// Concepts that were mistaken at least once and later mastered. The
    /// interesting number: not what you knew, what you fixed.
    var conceptsRepaired = 0
    var distinctActiveDays = 0

    static let empty = LearnerStats()
}

/// One badge and the single fact that earns it.
struct Achievement: Identifiable, Equatable, Sendable {
    /// The bar an achievement measures against. A case per measurable fact,
    /// rather than a closure, so the whole set is inspectable and testable as
    /// data — and so nothing can be awarded by code nobody can read.
    enum Requirement: Equatable, Sendable {
        case lessonsPassed(Int)
        case lessonsPassedFirstTry(Int)
        case conceptsMastered(Int)
        case drillsCompleted(Int)
        case drillsPerfect(Int)
        case programsRun(Int)
        case testsPassed(Int)
        case conceptsRepaired(Int)
        case activeDays(Int)

        var target: Int {
            switch self {
            case let .lessonsPassed(n), let .lessonsPassedFirstTry(n),
                 let .conceptsMastered(n), let .drillsCompleted(n),
                 let .drillsPerfect(n), let .programsRun(n),
                 let .testsPassed(n), let .conceptsRepaired(n),
                 let .activeDays(n):
                n
            }
        }

        func progress(in stats: LearnerStats) -> Int {
            switch self {
            case .lessonsPassed: stats.lessonsPassed
            case .lessonsPassedFirstTry: stats.lessonsPassedFirstTry
            case .conceptsMastered: stats.conceptsMastered
            case .drillsCompleted: stats.drillsCompleted
            case .drillsPerfect: stats.drillsPerfect
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
    let requirement: Requirement

    func isUnlocked(by stats: LearnerStats) -> Bool {
        requirement.progress(in: stats) >= requirement.target
    }

    /// Clamped to 1, so a bar never overshoots after the badge is earned.
    func fraction(of stats: LearnerStats) -> Double {
        guard requirement.target > 0 else { return 1 }
        return min(1, Double(requirement.progress(in: stats)) / Double(requirement.target))
    }

    func progressLabel(for stats: LearnerStats) -> String {
        "\(min(requirement.progress(in: stats), requirement.target)) / \(requirement.target)"
    }
}
