import Foundation

/// Persists attempts and derives mastery from them.
///
/// Mastery is always recomputed from the attempt log rather than stored as a
/// running total, so a scoring change never has to migrate anyone's history and
/// the evidence behind a review decision stays inspectable.
actor LearningProgressStore {
    private struct State: Codable {
        var attempts: [LessonAttempt]
    }

    private let storageURL: URL
    private let maximumAttempts = 500
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

    // MARK: - Storage

    private func state() throws -> State {
        if let cachedState { return cachedState }
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            let empty = State(attempts: [])
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
