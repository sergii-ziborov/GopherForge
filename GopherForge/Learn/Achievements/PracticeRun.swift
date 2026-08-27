import Foundation

/// One time the learner made the toolchain do something.
///
/// The project library keeps only the last build per project, which is right
/// for a recent-projects list and useless for "how much have you actually
/// done". This is the counted record: small, append-only, and derived from a
/// real `CompilationResult` rather than from a button press.
struct PracticeRun: Codable, Equatable, Sendable {
    let phase: CompilationResult.Phase
    let succeeded: Bool
    let testsPassed: Int
    let ranAt: Date

    init(result: CompilationResult, ranAt: Date = Date()) {
        phase = result.phase
        succeeded = result.succeeded
        testsPassed = result.phase == .test ? result.tests.passedCount : 0
        self.ranAt = ranAt
    }

    init(phase: CompilationResult.Phase, succeeded: Bool, testsPassed: Int, ranAt: Date) {
        self.phase = phase
        self.succeeded = succeeded
        self.testsPassed = testsPassed
        self.ranAt = ranAt
    }

    /// A program that compiled and executed. `build` is not counted: the badge
    /// is for making something run, not for type-checking it.
    var isProgramRun: Bool {
        phase == .run && succeeded
    }
}

/// Turns the evidence the app already keeps into the numbers badges are made
/// of.
///
/// Pure, and deliberately so: every achievement in the product can then be
/// tested against a hand-written history, with no store, no clock and no disk.
enum LearnerStatsBuilder {
    /// A concept counts as mastered above this strength. The same threshold the
    /// review scheduler treats as "not the weakest thing you could practise".
    static let masteryThreshold = 0.75

    static func build(
        attempts: [LessonAttempt],
        mastery: [ConceptMastery],
        drills: [MatchingDrillResult],
        runs: [PracticeRun],
        quizzes: [QuizResult] = []
    ) -> LearnerStats {
        var stats = LearnerStats()

        let passed = attempts.filter(\.succeeded)
        stats.lessonsPassed = Set(passed.map(\.lessonID)).count
        stats.lessonsPassedFirstTry = Set(
            passed.filter { $0.compileAttempts <= 1 && $0.mistakeTags.isEmpty }.map(\.lessonID)
        ).count

        let mastered = mastery.filter { $0.strength >= masteryThreshold }
        stats.conceptsMastered = mastered.count
        // Repaired means both things happened: it was wrong at least once, and
        // it is strong now. That is the number worth a badge.
        stats.conceptsRepaired = mastered.count { $0.mistakes > 0 }

        stats.drillsCompleted = drills.count
        stats.drillsPerfect = drills.count(where: \.isPerfect)

        // Counted by unit rather than by attempt: passing the same quiz five
        // times is one thing learned, not five.
        stats.quizzesPassed = Set(quizzes.filter(\.passed).map(\.unitID)).count
        stats.quizzesPerfect = Set(quizzes.filter(\.isPerfect).map(\.unitID)).count

        stats.programsRun = runs.count(where: \.isProgramRun)
        stats.testsPassed = runs.reduce(0) { $0 + $1.testsPassed }

        stats.distinctActiveDays = distinctDays(
            attempts.map(\.attemptedAt) + drills.map(\.completedAt)
                + runs.map(\.ranAt) + quizzes.map(\.completedAt)
        )

        return stats
    }

    private static func distinctDays(_ dates: [Date]) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return Set(dates.map { calendar.startOfDay(for: $0) }).count
    }
}
