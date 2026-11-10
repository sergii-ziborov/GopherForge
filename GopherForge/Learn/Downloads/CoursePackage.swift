import Foundation

/// A whole course is one versioned document. No lesson performs a download.
struct CoursePackage: Codable, Sendable {
    let schemaVersion: Int
    let id: String
    let revision: String
    let units: [CourseUnit]
    let readings: [ReadingLesson]
    let guides: [LessonGuide]
    let hints: [LessonHint]
    let solutions: [String: String]
    let interview: InterviewPrepBank?
    let labs: [DevOpsLab]
    let practice: CoursePractice
}

struct CoursePractice: Codable, Sendable {
    let quizzes: [Quiz]
    let drills: [MatchingDrill]
    let bugs: [SpotTheBugRound]
    let interviews: [InterviewQuestion]
    let reviewRounds: [MatchingDrill]
    let reviewPairs: [MatchingPair]
}

struct CourseDownload: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let revision: String
    let fileName: String
    let byteCount: Int
    let sha256: String
    let lessonIDs: [String]
    let unitCount: Int
    let teachingCount: Int
    let challengeCount: Int
    let interviewCount: Int
    let labCount: Int
    let interviewIDs: [String]?
}

struct DevOpsLab: Codable, Identifiable, Sendable {
    struct Check: Codable, Sendable {
        let path: String
        let description: String
        let equals: String?
        let sameAs: String?
        let sha256Of: String?
    }
    let id: String
    let title: String
    let objective: String
    let instructions: String
    let initialFiles: [String: String]
    let starter: String
    let checks: [Check]
}

enum CourseContentError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case let .invalid(message): message }
    }
}
