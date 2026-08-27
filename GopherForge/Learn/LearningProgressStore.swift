import Foundation

/// Persists attempts and derives mastery from them.
///
/// Mastery is always recomputed from the attempt log rather than stored as a
/// running total, so a scoring change never has to migrate anyone's history and
/// the evidence behind a review decision stays inspectable.
actor LearningProgressStore {
    private struct State: Codable {
        var attempts: [LessonAttempt]
        /// Optional so a file written before drills existed still decodes.
        /// A new field that is not optional turns every old install's history
        /// into a decode failure, which is a worse bug than a missing feature.
        var drills: [MatchingDrillResult]?
        var runs: [PracticeRun]?
        var quizzes: [QuizResult]?
    }

    private let storageURL: URL
    private let maximumAttempts = 500
    private let maximumDrills = 500
    private let maximumRuns = 1_000
    private var cachedState: State?

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.storageURL = applicationSupport
                .appending(path: "GopherForge", directoryHint: .isDirectory)
                .appending(path: "learning-progress.json")
        }
    }

    func attempts() throws -> [LessonAttempt] {
        try state().attempts.sorted { $0.attemptedAt > $1.attemptedAt }
    }

    func record(_ attempt: LessonAttempt) throws {
        var current = try state()
        current.attempts.append(attempt)
        if current.attempts.count > maximumAttempts {
            current.attempts = Array(current.attempts.suffix(maximumAttempts))
        }
        try persist(current)
    }

    func mastery() throws -> [ConceptMastery] {
        var byTag: [String: ConceptMastery] = [:]
        for attempt in try state().attempts.sorted(by: { $0.attemptedAt < $1.attemptedAt }) {
            let lessonTags = GoCourseCatalog.lesson(id: attempt.lessonID)?.conceptTags ?? []
            let mistaken = Set(attempt.mistakeTags)

            for tag in Set(lessonTags).union(mistaken) {
                var mastery = byTag[tag] ?? .empty(tag)
                // A tag is a mistake when it was observed as one; otherwise the
                // attempt's own outcome decides.
                let succeeded = mistaken.contains(tag) ? false : attempt.succeeded
                mastery.record(succeeded: succeeded, at: attempt.attemptedAt)
                byTag[tag] = mastery
            }
        }
        return byTag.values.sorted { $0.conceptTag < $1.conceptTag }
    }

    func completedLessonIDs() throws -> Set<String> {
        Set(try state().attempts.filter(\.succeeded).map(\.lessonID))
    }

    // MARK: - Drills and runs

    func drillResults() throws -> [MatchingDrillResult] {
        try state().drills ?? []
    }

    func record(_ result: MatchingDrillResult) throws {
        var current = try state()
        var drills = current.drills ?? []
        drills.append(result)
        current.drills = Array(drills.suffix(maximumDrills))
        try persist(current)
    }

    func quizResults() throws -> [QuizResult] {
        try state().quizzes ?? []
    }

    func record(_ result: QuizResult) throws {
        var current = try state()
        var quizzes = current.quizzes ?? []
        quizzes.append(result)
        current.quizzes = Array(quizzes.suffix(maximumDrills))
        try persist(current)
    }

    func practiceRuns() throws -> [PracticeRun] {
        try state().runs ?? []
    }

    /// Only successful work is counted. A build that failed is evidence for
    /// review, not something to award a badge for, and counting attempts would
    /// make every badge a measure of persistence rather than of progress.
    func record(_ run: PracticeRun) throws {
        guard run.succeeded else { return }
        var current = try state()
        var runs = current.runs ?? []
        runs.append(run)
        current.runs = Array(runs.suffix(maximumRuns))
        try persist(current)
    }

    /// Everything a badge is made of, assembled in one read so the Learn screen
    /// does not hit the store four times to draw one list.
    func learnerStats() throws -> LearnerStats {
        LearnerStatsBuilder.build(
            attempts: try attempts(),
            mastery: try mastery(),
            drills: try drillResults(),
            runs: try practiceRuns(),
            quizzes: try quizResults()
        )
    }

    // MARK: - Storage

    private func state() throws -> State {
        if let cachedState { return cachedState }
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            let empty = State(attempts: [], drills: [], runs: [], quizzes: [])
            cachedState = empty
            return empty
        }
        let decoded = try JSONDecoder.gopherForge.decode(
            State.self,
            from: try Data(contentsOf: storageURL)
        )
        cachedState = decoded
        return decoded
    }

    private func persist(_ state: State) throws {
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.gopherForge.encode(state).write(to: storageURL, options: .atomic)
        cachedState = state
    }
}
