import Foundation

/// Chooses what to review next.
///
/// The rule is simple and deliberately not a black box: weakest concept first,
/// with anything mistaken recently pulled forward, and never the same lesson
/// twice in one session. A learner can be shown exactly why an item appeared.
struct ReviewScheduler: Sendable {
    struct Item: Identifiable, Equatable, Sendable {
        let lesson: Lesson
        let conceptTag: String
        let reason: String
        let priority: Double

        var id: String { "\(lesson.id)#\(conceptTag)" }
    }

    private let catalog: [Lesson]

    init(catalog: [Lesson] = GoCourseCatalog.lessons) {
        self.catalog = catalog
    }

    func nextItems(
        mastery: [ConceptMastery],
        excluding recentLessonIDs: Set<String> = [],
        limit: Int = 5
    ) -> [Item] {
        let ranked = mastery
            .filter { $0.successes + $0.mistakes > 0 }
            .sorted { lhs, rhs in
                if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
                return (lhs.lastMistakeAt ?? .distantPast) > (rhs.lastMistakeAt ?? .distantPast)
            }

        var items: [Item] = []
        var usedLessons = recentLessonIDs

        for concept in ranked {
            guard items.count < limit else { break }
            let candidates = catalog
                .filter { $0.conceptTags.contains(concept.conceptTag) }
                .filter { !usedLessons.contains($0.id) }
            guard let lesson = candidates.first else { continue }
            usedLessons.insert(lesson.id)
            items.append(
                Item(
                    lesson: lesson,
                    conceptTag: concept.conceptTag,
                    reason: reason(for: concept),
                    priority: 1 - concept.strength
                )
            )
        }

        return items
    }

    private func reason(for concept: ConceptMastery) -> String {
        if concept.successes == 0 {
            return "You have not got this right yet."
        }
        if let lastMistakeAt = concept.lastMistakeAt,
           Date().timeIntervalSince(lastMistakeAt) < 86_400 {
            return "You missed this today."
        }
        if concept.mistakes > concept.successes {
            return "More misses than hits so far."
        }
        return "Due for a check."
    }
}
