import Foundation

/// Every badge in the product, and the rungs each one has.
///
/// Each is earned by doing the thing the product is for — compiling, running,
/// testing, fixing — rather than by opening screens or by time spent. Levels
/// rather than single bars, because a badge that finishes at ten runs stops
/// saying anything on the eleventh, and the person still running programs a
/// month later is the one worth recognising.
enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "programs.run",
            title: "The forge",
            detail: "Compile and run Go programs on device",
            symbol: "hammer.fill",
            measure: .programsRun,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "First forge"),
                AchievementLevel(rank: .silver, target: 10, title: "Anvil warmed"),
                AchievementLevel(rank: .gold, target: 50, title: "Smith"),
                AchievementLevel(rank: .platinum, target: 200, title: "Master smith"),
            ]
        ),
        Achievement(
            id: "lessons.passed",
            title: "The course",
            detail: "Pass lessons",
            symbol: "book.fill",
            measure: .lessonsPassed,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Opening move"),
                AchievementLevel(rank: .silver, target: 10, title: "Course underway"),
                AchievementLevel(rank: .gold, target: 25, title: "Well read"),
                AchievementLevel(rank: .platinum, target: 40, title: "Every lesson"),
            ]
        ),
        Achievement(
            id: "lessons.firstTry",
            title: "Clean first compile",
            detail: "Pass lessons on the first compile, with nothing to fix",
            symbol: "bolt.fill",
            measure: .lessonsPassedFirstTry,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Straight through"),
                AchievementLevel(rank: .silver, target: 5, title: "Sure footed"),
                AchievementLevel(rank: .gold, target: 15, title: "Compiles in your head"),
                AchievementLevel(rank: .platinum, target: 30, title: "The compiler agrees"),
            ]
        ),
        Achievement(
            id: "tests.passed",
            title: "Green bar",
            detail: "Make tests pass",
            symbol: "checkmark.diamond.fill",
            measure: .testsPassed,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "First green"),
                AchievementLevel(rank: .silver, target: 20, title: "Table driven"),
                AchievementLevel(rank: .gold, target: 75, title: "Well covered"),
                AchievementLevel(rank: .platinum, target: 200, title: "Nothing untested"),
            ]
        ),
        Achievement(
            id: "concepts.mastered",
            title: "Understanding",
            detail: "Bring concepts up to strength",
            symbol: "brain.head.profile",
            measure: .conceptsMastered,
            levels: [
                AchievementLevel(rank: .bronze, target: 3, title: "Getting it"),
                AchievementLevel(rank: .silver, target: 10, title: "Fluent"),
                AchievementLevel(rank: .gold, target: 20, title: "It clicked"),
                AchievementLevel(rank: .platinum, target: 35, title: "Second nature"),
            ]
        ),
        Achievement(
            id: "concepts.repaired",
            title: "Repaired",
            detail: "Master a concept you once got wrong — not what you knew, what you fixed",
            symbol: "wrench.and.screwdriver.fill",
            measure: .conceptsRepaired,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Put right"),
                AchievementLevel(rank: .silver, target: 5, title: "Learned from it"),
                AchievementLevel(rank: .gold, target: 12, title: "Nothing left broken"),
                AchievementLevel(rank: .platinum, target: 25, title: "Rebuilt"),
            ]
        ),
        Achievement(
            id: "drills.completed",
            title: "Drills",
            detail: "Finish matching drills",
            symbol: "link",
            measure: .drillsCompleted,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Paired up"),
                AchievementLevel(rank: .silver, target: 10, title: "Quick hands"),
                AchievementLevel(rank: .gold, target: 30, title: "Pattern matcher"),
                AchievementLevel(rank: .platinum, target: 60, title: "Instant"),
            ]
        ),
        Achievement(
            id: "drills.perfect",
            title: "No wrong moves",
            detail: "Finish drills with no wrong connection",
            symbol: "star.fill",
            measure: .drillsPerfect,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Spotless"),
                AchievementLevel(rank: .silver, target: 5, title: "Clean sweep"),
                AchievementLevel(rank: .gold, target: 15, title: "Unerring"),
                AchievementLevel(rank: .platinum, target: 30, title: "Never a slip"),
            ]
        ),
        Achievement(
            id: "quizzes.passed",
            title: "Units finished",
            detail: "Pass the quiz at the end of a unit",
            symbol: "graduationcap.fill",
            measure: .quizzesPassed,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Quizzed"),
                AchievementLevel(rank: .silver, target: 3, title: "Three units down"),
                AchievementLevel(rank: .gold, target: 5, title: "Most of the way"),
                AchievementLevel(rank: .platinum, target: 7, title: "Every unit"),
            ]
        ),
        Achievement(
            id: "quizzes.perfect",
            title: "Full marks",
            detail: "Answer every question in a unit's quiz correctly",
            symbol: "rosette",
            measure: .quizzesPerfect,
            levels: [
                AchievementLevel(rank: .bronze, target: 1, title: "Perfect round"),
                AchievementLevel(rank: .silver, target: 3, title: "Three perfect"),
                AchievementLevel(rank: .gold, target: 5, title: "Hardly a doubt"),
                AchievementLevel(rank: .platinum, target: 7, title: "Flawless"),
            ]
        ),
        Achievement(
            id: "days.active",
            title: "Kept at it",
            detail: "Come back and build something on different days",
            symbol: "calendar",
            measure: .activeDays,
            levels: [
                AchievementLevel(rank: .bronze, target: 2, title: "Came back"),
                AchievementLevel(rank: .silver, target: 7, title: "A week of it"),
                AchievementLevel(rank: .gold, target: 21, title: "A habit"),
                AchievementLevel(rank: .platinum, target: 60, title: "Part of the day"),
            ]
        ),
    ]

    /// Badges with at least one level earned.
    static func unlocked(by stats: LearnerStats) -> [Achievement] {
        all.filter { $0.isUnlocked(by: stats) }
    }

    /// Every rung earned across every badge — the number that keeps going up,
    /// which is what a progress line on the home screen should show.
    static func earnedLevelCount(by stats: LearnerStats) -> Int {
        all.reduce(0) { $0 + $1.earnedLevelCount(for: stats) }
    }

    static var totalLevelCount: Int {
        all.reduce(0) { $0 + $1.levels.count }
    }

    /// Closest to its next rung first, so the top of the list is whatever is
    /// nearly earned. Finished badges sink to the bottom: they have nothing
    /// left to say.
    static func ordered(by stats: LearnerStats) -> [Achievement] {
        all.sorted { left, right in
            let leftDone = left.isComplete(for: stats)
            let rightDone = right.isComplete(for: stats)
            if leftDone != rightDone { return !leftDone }
            return left.fraction(of: stats) > right.fraction(of: stats)
        }
    }
}
