import Foundation

/// Everything there is to practise, and what unlocks it.
///
/// Practice is gathered here rather than scattered through the units for two
/// reasons. A question with an answer is not the same thing as a lesson with
/// something to build, and mixing them makes a unit read as half tutorial and
/// half quiz. And practice that arrives as you earn it is worth coming back
/// for, where a list that is complete on day one is just a longer list.
enum PracticeCatalog {
    /// One thing to practise.
    struct Item: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// A predict-the-output challenge lifted out of its unit.
            case challenge(Lesson)
            case drill(MatchingDrill)
            case quiz(Quiz)
            /// A short program with one thing wrong in it.
            case spotTheBug([SpotTheBugRound])
            /// Questions a Go interview asks, with what a strong answer covers.
            case interview([InterviewQuestion])
        }

        let kind: Kind
        let unitID: String
        /// Completed lessons in this unit before the item appears.
        let unlocksAfter: Int

        var id: String {
            switch kind {
            case let .challenge(lesson): "challenge.\(lesson.id)"
            case let .drill(drill): "drill.\(drill.id)"
            case let .quiz(quiz): "quiz.\(quiz.unitID)"
            case .spotTheBug: "bug.\(unitID)"
            case .interview: "interview.\(unitID)"
            }
        }

        var title: String {
            switch kind {
            case let .challenge(lesson): lesson.title
            case let .drill(drill): drill.title
            case let .quiz(quiz): quiz.title
            case .spotTheBug: "Spot the bug"
            case .interview: "Interview questions"
            }
        }

        var detail: String {
            switch kind {
            case let .challenge(lesson): lesson.objective
            case let .drill(drill): "\(drill.pairs.count) pairs to connect"
            case let .quiz(quiz): "\(quiz.questions.count) questions · four in five passes"
            case let .spotTheBug(rounds): "\(rounds.count) programs, one fault each"
            case let .interview(questions): "\(questions.count) asked out loud, then compared"
            }
        }

        var symbol: String {
            switch kind {
            case .challenge: "questionmark.circle"
            case .drill: "link"
            case .quiz: "checklist"
            case .spotTheBug: "magnifyingglass"
            case .interview: "mic"
            }
        }

        func isUnlocked(completedInUnit: Int) -> Bool {
            completedInUnit >= unlocksAfter
        }
    }

    /// In the order the course teaches, so practice arrives beside the unit it
    /// belongs to rather than in a heap.
    static var items: [Item] {
        GoCourseCatalog.units.flatMap { unit -> [Item] in
            var built: [Item] = []
            // The first challenge of a unit is open from the start and the
            // rest arrive one lesson at a time. Making even the first one wait
            // turns the way into a unit into a barrier, and a prediction is
            // often the best way in: it asks a question the lesson answers.
            for (index, challenge) in unit.challenges.enumerated() {
                built.append(
                    Item(kind: .challenge(challenge), unitID: unit.id, unlocksAfter: index)
                )
            }
            // Drills are open from the start. A practice screen that is
            // entirely locked on a fresh install is a punishment rather than
            // something to come back to, and matching terms is a reasonable
            // way in for someone who has read nothing yet.
            for drill in MatchingDrillCatalog.drills(forUnit: unit.id) {
                built.append(Item(kind: .drill(drill), unitID: unit.id, unlocksAfter: 0))
            }
            // The bug hunt is open from the start. Reading code and noticing
            // what is off does not need the unit read first — it is often the
            // reason somebody opens the unit.
            let rounds = SpotTheBugCatalog.rounds(forUnit: unit.id)
            if !rounds.isEmpty {
                built.append(Item(kind: .spotTheBug(rounds), unitID: unit.id, unlocksAfter: 0))
            }
            // Interview questions wait until the unit is finished. They are
            // about explaining, and explaining something you have not built is
            // how people learn to recite.
            let interview = InterviewCatalog.questions(forUnit: unit.id)
            if !interview.isEmpty {
                built.append(
                    Item(
                        kind: .interview(interview),
                        unitID: unit.id,
                        unlocksAfter: unit.teachingLessons.count
                    )
                )
            }
            if let quiz = QuizCatalog.quiz(forUnit: unit.id) {
                // The quiz waits until the unit has been started. Gating it
                // behind the whole unit sounds rigorous and mostly stops people
                // checking what they know, which is what a quiz is for.
                built.append(Item(kind: .quiz(quiz), unitID: unit.id, unlocksAfter: 1))
            }
            return built
        }
    }

    static func items(forUnit unitID: String) -> [Item] {
        items.filter { $0.unitID == unitID }
    }

    /// How many of a unit's teaching lessons are done.
    static func completedCount(inUnit unitID: String, completed: Set<String>) -> Int {
        guard let unit = GoCourseCatalog.units.first(where: { $0.id == unitID }) else { return 0 }
        return unit.teachingLessons.count { completed.contains($0.id) }
    }

    static func unlockedItems(completed: Set<String>) -> [Item] {
        items.filter { item in
            item.isUnlocked(completedInUnit: completedCount(inUnit: item.unitID, completed: completed))
        }
    }
}
