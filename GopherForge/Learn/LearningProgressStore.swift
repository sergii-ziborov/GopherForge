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
        var corrections: [MistakeReviewAttempt]?
    }

    private let storageURL: URL
    nonisolated let drafts: LessonDraftStore
    private let maximumAttempts = 500
    private let maximumDrills = 500
    private let maximumRuns = 1_000
    private var cachedState: State?

    /// The store the app uses.
    ///
    /// Shared rather than made per screen, because the cache above turns a
    /// second instance from a waste into a correctness bug: marking a lesson
    /// done updated the cache of whichever store the lesson screen happened to
    /// hold, while the course screen's own store went on answering from the
    /// cache it had read at launch. Progress appeared only after a relaunch —
    /// which is the thing that re-read the file. Tests still make their own
    /// with an explicit `storageURL`.
    static let shared = LearningProgressStore()

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
        drafts = LessonDraftStore(folder: self.storageURL.deletingPathExtension().appendingPathExtension("drafts"))
    }

    func attempts() throws -> [LessonAttempt] {
        try state().attempts.sorted { $0.attemptedAt > $1.attemptedAt }
    }

    func record(_ attempt: LessonAttempt) throws {
        var current = try state()
        current.attempts = retainedAttempts(current.attempts + [attempt])
        try persist(current)
    }

    /// Recent failures may age out; a completed lesson and its compiler proof
    /// must survive. Keep both the latest pass and latest verified pass so a
    /// later hand tick cannot erase a compiler badge when history is trimmed.
    private func retainedAttempts(_ attempts: [LessonAttempt]) -> [LessonAttempt] {
        guard attempts.count > maximumAttempts else { return attempts }
        var latestPass: [String: Int] = [:]
        var latestVerified: [String: Int] = [:]
        for (index, attempt) in attempts.enumerated() where attempt.succeeded {
            latestPass[attempt.lessonID] = index
            if attempt.isCompilerVerified { latestVerified[attempt.lessonID] = index }
        }
        var keep = Set(latestPass.values).union(latestVerified.values)
        for index in attempts.indices.reversed() where keep.count < maximumAttempts {
            keep.insert(index)
        }
        return keep.sorted().map { attempts[$0] }
    }

    func mastery() throws -> [ConceptMastery] {
        var byTag: [String: ConceptMastery] = [:]
        for event in try evidence() {
            var mastery = byTag[event.tag] ?? .empty(event.tag)
            mastery.record(succeeded: event.succeeded, at: event.date)
            byTag[event.tag] = mastery
        }
        return byTag.values.sorted { $0.conceptTag < $1.conceptTag }
    }

    func pendingMistakeConcepts() throws -> [String] {
        LearningEvidence.pendingConcepts(in: try evidence())
    }

    func correctionAttempts() throws -> [MistakeReviewAttempt] { try state().corrections ?? [] }

    func record(_ attempt: MistakeReviewAttempt) throws {
        var current = try state()
        current.corrections = retainedCorrections((current.corrections ?? []) + [attempt])
        try persist(current)
    }

    func recordMistakes(conceptTags: [String], at date: Date = Date()) throws {
        guard !conceptTags.isEmpty else { return }
        var current = try state()
        let mistakes = Set(conceptTags).sorted().map {
            MistakeReviewAttempt(conceptTag: $0, succeeded: false, attemptedAt: date)
        }
        current.corrections = retainedCorrections((current.corrections ?? []) + mistakes)
        try persist(current)
    }

    private func evidence() throws -> [LearningEvidence.Event] {
        let current = try state()
        return LearningEvidence.events(
            attempts: current.attempts, drills: current.drills ?? [],
            quizzes: current.quizzes ?? [], corrections: current.corrections ?? []
        )
    }

    /// Keep the latest state of every concept and question when trimming the
    /// recent history. Otherwise an old quiz error could reappear merely
    /// because its correction fell off the end of the bounded log.
    private func retainedCorrections(_ attempts: [MistakeReviewAttempt]) -> [MistakeReviewAttempt] {
        guard attempts.count > maximumRuns else { return attempts }
        var latest: [String: Int] = [:]
        for (index, attempt) in attempts.enumerated() {
            latest["concept." + attempt.conceptTag] = index
            if let id = attempt.questionID { latest["question." + id] = index }
        }
        var keep = Set(latest.values)
        for index in attempts.indices.reversed() where keep.count < maximumRuns { keep.insert(index) }
        return keep.sorted().map { attempts[$0] }
    }

    func completedLessonIDs() throws -> Set<String> {
        Set(try state().attempts.filter(\.succeeded).map(\.lessonID))
    }

    /// Lessons the compiler actually witnessed passing, as distinct from the
    /// ones the learner ticked. The course marks the two differently, because
    /// claiming the compiler agreed when it never ran would be a lie the app
    /// tells on the learner's behalf.
    func compilerVerifiedLessonIDs() throws -> Set<String> {
        Set(
            try state().attempts
                .filter { $0.succeeded && $0.isCompilerVerified }
                .map(\.lessonID)
        )
    }

    /// Undoes a tick the learner made by hand.
    ///
    /// Only self-reported passes are removed: a lesson the compiler passed
    /// happened, and forgetting it on request would throw away the evidence
    /// review is built from. Returns whether anything changed.
    @discardableResult
    func clearSelfReportedCompletion(lessonID: String) throws -> Bool {
        var current = try state()
        let before = current.attempts.count
        current.attempts.removeAll { $0.lessonID == lessonID && $0.isSelfReported }
        guard current.attempts.count != before else { return false }
        try persist(current)
        return true
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

    /// Forgets everything: attempts, drills, quizzes and runs.
    ///
    /// A learner who wants to start the course again should be able to, and
    /// there is no other way to undo a lesson marked complete by mistake.
    func reset() throws {
        try persist(State(attempts: [], drills: [], runs: [], quizzes: []))
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
