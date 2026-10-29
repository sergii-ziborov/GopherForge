import Foundation

/// An explicit, public, read-only summary; never includes attempts, drafts or source.
struct LearningShareSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let source: String
    let completed: [String]
    let compilerVerified: [String]
    let assessments: [String: String]
    let lastLessonID: String?
    let lastInterviewID: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, source, completed, compilerVerified, assessments, lastLessonID, lastInterviewID
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion); try c.encode(source, forKey: .source)
        try c.encode(completed, forKey: .completed); try c.encode(compilerVerified, forKey: .compilerVerified)
        try c.encode(assessments, forKey: .assessments)
        try c.encode(lastLessonID, forKey: .lastLessonID); try c.encode(lastInterviewID, forKey: .lastInterviewID)
    }

    @MainActor static func make(store: LearningProgressStore = .shared, defaults: UserDefaults = .standard) async throws -> Self {
        let known = Set(GoCourseCatalog.units.flatMap(\.lessons).map(\.id))
        let interview = Set(InterviewPrepBank.shared.questions.map(\.id))
        let completed = try await store.completedLessonIDs().intersection(known)
        let verified = try await store.compilerVerifiedLessonIDs().intersection(completed)
        let raw = defaults.string(forKey: "interview.preparation.selfAssessment.v1") ?? "{}"
        let marks = (try? JSONDecoder().decode([String: String].self, from: Data(raw.utf8))) ?? [:]
        let lesson = defaults.string(forKey: "learning.lastLesson.v1")
        let question = defaults.string(forKey: "learning.lastInterview.v1")
        return Self(schemaVersion: 1, source: "app", completed: completed.sorted(), compilerVerified: verified.sorted(),
                    assessments: marks.filter { interview.contains($0.key) && ["understood", "revisit"].contains($0.value) },
                    lastLessonID: lesson.flatMap { known.contains($0) ? $0 : nil },
                    lastInterviewID: question.flatMap { interview.contains($0) ? $0 : nil })
    }
}
