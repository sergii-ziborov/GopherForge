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

/// Which downloadable course owns a unit. Unit and lesson IDs never change when
/// a unit moves into a dedicated course, so progress keeps its meaning.
enum CourseMembership {
    struct Course: Sendable {
        let id: String
        let units: [String]
    }
    static let devopsUnits: Set<String> = ["operations", "containers", "kubernetes", "devops"]
    /// Shown below the Go path on Learn, in this order.
    static let specialized: [Course] = [
        Course(id: "gin", units: ["gin-foundations", "gin", "gin-project", "gin-data", "gin-edge"]),
        Course(id: "blockchain", units: ["blockchain-foundations", "blockchain"]),
        Course(id: "security", units: ["security", "security-web", "security-operations"]),
        Course(id: "gamedev", units: ["gamedev-loop", "gamedev-systems"]),
    ]

    static func courseID(forUnit unitID: String) -> String {
        if devopsUnits.contains(unitID) { return "devops" }
        return specialized.first { $0.units.contains(unitID) }?.id ?? "go"
    }
}

extension CoursePackage {
    /// The same document without some of its units and everything that only
    /// those units' lessons use.
    func removing(units removed: Set<String>) -> CoursePackage {
        let kept = units.filter { !removed.contains($0.id) }
        let lessonIDs = Set(kept.flatMap(\.lessons).map(\.id))
        return CoursePackage(
            schemaVersion: schemaVersion, id: id, revision: revision, units: kept,
            readings: readings.filter { lessonIDs.contains($0.id) },
            guides: guides.filter { lessonIDs.contains($0.id) },
            hints: hints.filter { lessonIDs.contains($0.lessonID) },
            solutions: solutions.filter { lessonIDs.contains($0.key) },
            interview: interview, labs: labs,
            practice: CoursePractice(
                quizzes: practice.quizzes.filter { !removed.contains($0.unitID) },
                drills: practice.drills.filter { !removed.contains($0.unitID) },
                bugs: practice.bugs.filter { !removed.contains($0.unitID) },
                interviews: practice.interviews.filter { !removed.contains($0.unitID) },
                reviewRounds: practice.reviewRounds.filter { !removed.contains($0.unitID) },
                reviewPairs: practice.reviewPairs.filter { $0.requiredLessonID.map(lessonIDs.contains) ?? true }))
    }
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
