import Foundation

/// The learner's progress, held once and read by every screen that shows it.
///
/// It used to be a `Set<String>` loaded on the course screen and handed down by
/// value. That is a photograph: marking a lesson inside it wrote to disk and
/// changed nothing anybody could see, because the unit list was still holding
/// the copy it was given when it was built. Progress was only visible after
/// relaunching the app.
///
/// One observable object, refreshed when something is recorded, so the tick
/// appears where the learner expects it — on the lesson, in the unit, and in
/// the ring on the course screen.
@MainActor
@Observable
final class LearnProgress {
    private(set) var completed: Set<String> = []
    /// The subset the compiler witnessed. The rest were ticked by hand.
    private(set) var compilerVerified: Set<String> = []
    private(set) var mastery: [ConceptMastery] = []
    private(set) var stats: LearnerStats = .empty

    private let store: LearningProgressStore

    init(store: LearningProgressStore = .shared) {
        self.store = store
    }

    func refresh() async {
        completed = (try? await store.completedLessonIDs()) ?? []
        compilerVerified = (try? await store.compilerVerifiedLessonIDs()) ?? []
        mastery = (try? await store.mastery()) ?? []
        stats = (try? await store.learnerStats()) ?? .empty
    }

    func isCompleted(_ lessonID: String) -> Bool { completed.contains(lessonID) }

    func isCompilerVerified(_ lessonID: String) -> Bool { compilerVerified.contains(lessonID) }

    /// The learner says they have done it.
    func markCompleted(_ lesson: Lesson) async {
        guard !completed.contains(lesson.id) else { return }
        try? await store.record(
            LessonAttempt(
                lessonID: lesson.id,
                succeeded: true,
                mistakeTags: [],
                compileAttempts: 0,
                compilerVerified: false
            )
        )
        await refresh()
    }

    /// Undoes a tick made by hand. A pass the compiler witnessed stays.
    func clearCompletion(_ lesson: Lesson) async {
        _ = try? await store.clearSelfReportedCompletion(lessonID: lesson.id)
        await refresh()
    }

    /// How many of a unit's teaching lessons are done.
    func completedCount(in unit: CourseUnit) -> Int {
        unit.teachingLessons.count { completed.contains($0.id) }
    }

    func record(_ result: QuizResult) async {
        try? await store.record(result)
        await refresh()
    }

    func record(_ result: MatchingDrillResult) async {
        try? await store.record(result)
        await refresh()
    }
}
