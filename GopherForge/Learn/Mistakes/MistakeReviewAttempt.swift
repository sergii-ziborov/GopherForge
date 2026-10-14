import Foundation

/// A single answer is saved immediately, even if the learner leaves mid-run.
/// A nil question ID represents a mistake observed in the project compiler.
struct MistakeReviewAttempt: Codable, Equatable, Sendable {
    let questionID: String?
    let conceptTag: String
    let succeeded: Bool
    let attemptedAt: Date

    init(questionID: String? = nil, conceptTag: String, succeeded: Bool, attemptedAt: Date = Date()) {
        self.questionID = questionID
        self.conceptTag = conceptTag
        self.succeeded = succeeded
        self.attemptedAt = attemptedAt
    }
}

enum LearningEvidence {
    struct Event {
        let tag: String
        let succeeded: Bool
        let date: Date
    }

    static func events(
        attempts: [LessonAttempt], drills: [MatchingDrillResult],
        quizzes: [QuizResult], corrections: [MistakeReviewAttempt]
    ) -> [Event] {
        var result: [Event] = []
        for attempt in attempts {
            let tags = Set(GoCourseCatalog.lesson(id: attempt.lessonID)?.conceptTags ?? [])
                .union(attempt.mistakeTags)
            for tag in tags {
                result.append(Event(
                    tag: tag, succeeded: attempt.succeeded && !attempt.mistakeTags.contains(tag),
                    date: attempt.attemptedAt
                ))
            }
        }
        for drill in drills {
            result += drill.mistakenConcepts.map { Event(tag: $0, succeeded: false, date: drill.completedAt) }
        }
        for quiz in quizzes {
            let tags = Set(QuizCatalog.quiz(forUnit: quiz.unitID)?.questions.map(\.conceptTag) ?? [])
                .union(quiz.mistakenConcepts)
            for tag in tags {
                result.append(Event(tag: tag, succeeded: !quiz.mistakenConcepts.contains(tag), date: quiz.completedAt))
            }
        }
        result += corrections.map { Event(tag: $0.conceptTag, succeeded: $0.succeeded, date: $0.attemptedAt) }
        // Preserve input order at equal timestamps: a correction made at the
        // same instant as its source mistake still takes precedence.
        return result.enumerated().sorted {
            $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date
        }.map(\.element)
    }

    static func pendingConcepts(in events: [Event]) -> [String] {
        var pending: [String: Date] = [:]
        for event in events {
            if event.succeeded { pending.removeValue(forKey: event.tag) }
            else { pending[event.tag] = event.date }
        }
        return pending.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }.map(\.key)
    }
}
