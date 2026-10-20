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
    private(set) var pendingMistakeConcepts: [String] = []
    private(set) var correctionAttempts: [MistakeReviewAttempt] = []
    var confirmedConcepts: Set<String> {
        Set(correctionAttempts.filter(\.succeeded).map(\.conceptTag))
    }

    /// Bookmarks are independent of attempts: opening a lesson is not a pass.
    private(set) var lastLessonID: String?
    private(set) var lastInterviewID: String?
    private let bookmarks: UserDefaults
    private static let lessonBookmarkKey = "learning.lastLesson.v1"
    private static let interviewBookmarkKey = "learning.lastInterview.v1"

    var resumeLesson: Lesson? {
        lastLessonID.flatMap { GoCourseCatalog.lesson(id: $0) }
    }

    var resumeInterview: InterviewPrepQuestion? {
        InterviewPrepBank.shared.questions.first { $0.id == lastInterviewID }
    }

    func visitLesson(_ id: String) {
        guard GoCourseCatalog.lesson(id: id) != nil else { return }
        lastLessonID = id
        bookmarks.set(id, forKey: Self.lessonBookmarkKey)
        bookmarks.set(0, forKey: "learning.lastArea.v1")
    }

    func visitInterview(_ id: String) {
        guard InterviewPrepBank.shared.questions.contains(where: { $0.id == id }) else { return }
        lastInterviewID = id
        bookmarks.set(id, forKey: Self.interviewBookmarkKey)
        bookmarks.set(1, forKey: "learning.lastArea.v1")
    }

    private let store: LearningProgressStore

    init(store: LearningProgressStore = .shared, bookmarks: UserDefaults = .standard) {
        self.store = store
        self.bookmarks = bookmarks
        lastLessonID = bookmarks.string(forKey: Self.lessonBookmarkKey)
        lastInterviewID = bookmarks.string(forKey: Self.interviewBookmarkKey)
    }

    func refresh() async {
        completed = (try? await store.completedLessonIDs()) ?? []
        compilerVerified = (try? await store.compilerVerifiedLessonIDs()) ?? []
        mastery = (try? await store.mastery()) ?? []
        stats = (try? await store.learnerStats()) ?? .empty
        pendingMistakeConcepts = (try? await store.pendingMistakeConcepts()) ?? []
        correctionAttempts = (try? await store.correctionAttempts()) ?? []
    }

    func isCompleted(_ lessonID: String) -> Bool { completed.contains(lessonID) }

    func isCompilerVerified(_ lessonID: String) -> Bool { compilerVerified.contains(lessonID) }

    /// The learner says they have done it. Compile lessons refuse: Check is
    /// the only pass, and Next is the skip.
    func markCompleted(_ lesson: Lesson) async {
        guard lesson.canSelfReport, !completed.contains(lesson.id) else { return }
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

    /// Return only after the answer is durable; a dismissed question must not
    /// look corrected on the next launch if the write failed.
    func record(_ attempt: MistakeReviewAttempt) async throws {
        try await store.record(attempt)
        await refresh()
    }
}
