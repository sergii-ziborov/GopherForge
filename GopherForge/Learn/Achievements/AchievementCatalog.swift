import Foundation

/// Every badge in the product.
///
/// Each one is earned by doing the thing the product is for — compiling,
/// running, testing, fixing — rather than by opening screens or by time spent.
/// The ones worth having are at the bottom: passing on the first compile, and
/// repairing a concept you once got wrong.
enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "first.build",
            title: "First forge",
            detail: "Compile and run a Go program on device",
            symbol: "hammer.fill",
            requirement: .programsRun(1)
        ),
        Achievement(
            id: "ten.runs",
            title: "Anvil warmed",
            detail: "Run ten programs",
            symbol: "flame.fill",
            requirement: .programsRun(10)
        ),
        Achievement(
            id: "first.lesson",
            title: "Opening move",
            detail: "Pass your first lesson",
            symbol: "checkmark.seal.fill",
            requirement: .lessonsPassed(1)
        ),
        Achievement(
            id: "ten.lessons",
            title: "Course underway",
            detail: "Pass ten lessons",
            symbol: "book.fill",
            requirement: .lessonsPassed(10)
        ),
        Achievement(
            id: "first.tests",
            title: "Green bar",
            detail: "Make a package's tests pass",
            symbol: "testtube.2",
            requirement: .testsPassed(1)
        ),
        Achievement(
            id: "twenty.tests",
            title: "Table driven",
            detail: "Pass twenty tests",
            symbol: "list.bullet.rectangle",
            requirement: .testsPassed(20)
        ),
        Achievement(
            id: "first.drill",
            title: "Paired up",
            detail: "Finish a matching drill",
            symbol: "link",
            requirement: .drillsCompleted(1)
        ),
        Achievement(
            id: "three.perfect",
            title: "Clean sweep",
            detail: "Finish three drills with no wrong connection",
            symbol: "star.fill",
            requirement: .drillsPerfect(3)
        ),
        Achievement(
            id: "first.quiz",
            title: "Quizzed",
            detail: "Pass a unit's quiz",
            symbol: "checklist",
            requirement: .quizzesPassed(1)
        ),
        Achievement(
            id: "three.quizzes",
            title: "Three units down",
            detail: "Pass the quiz for three different units",
            symbol: "graduationcap.fill",
            requirement: .quizzesPassed(3)
        ),
        Achievement(
            id: "perfect.quiz",
            title: "Full marks",
            detail: "Answer every question in a unit's quiz correctly",
            symbol: "sparkles",
            requirement: .quizzesPerfect(1)
        ),
        Achievement(
            id: "five.concepts",
            title: "Five under the belt",
            detail: "Master five concepts",
            symbol: "brain.head.profile",
            requirement: .conceptsMastered(5)
        ),
        Achievement(
            id: "first.try",
            title: "Compiles first time",
            detail: "Pass five lessons without a failed compile",
            symbol: "bolt.fill",
            requirement: .lessonsPassedFirstTry(5)
        ),
        Achievement(
            id: "repaired",
            title: "Learned the hard way",
            detail: "Master three concepts you once got wrong",
            symbol: "arrow.uturn.up.circle.fill",
            requirement: .conceptsRepaired(3)
        ),
        Achievement(
            id: "seven.days",
            title: "Kept at it",
            detail: "Practise on seven different days",
            symbol: "calendar",
            requirement: .activeDays(7)
        ),
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    /// Unlocked first, then whatever is closest to being earned — so the list
    /// opens on what you did and points at what is one step away.
    static func ordered(by stats: LearnerStats) -> [Achievement] {
        all.sorted { first, second in
            let firstDone = first.isUnlocked(by: stats)
            let secondDone = second.isUnlocked(by: stats)
            if firstDone != secondDone { return firstDone }
            let firstFraction = first.fraction(of: stats)
            let secondFraction = second.fraction(of: stats)
            if firstFraction != secondFraction { return firstFraction > secondFraction }
            return first.id < second.id
        }
    }

    static func unlocked(by stats: LearnerStats) -> [Achievement] {
        all.filter { $0.isUnlocked(by: stats) }
    }
}
