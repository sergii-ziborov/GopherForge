import Foundation

/// Shared, authored interview preparation. This resource is copied byte-for-byte
/// into the web build; progress stays separate from compiler-verified lessons.
struct InterviewPrepBank: Codable, Sendable {
    let schemaVersion: Int
    let reviewedOn: String
    let levels: [String]
    let topics: [InterviewPrepTopic]
    let questions: [InterviewPrepQuestion]
    let demonstrations: [AlgorithmDemonstration]

    #if !LESSON_CATALOG_EXPORT
    static var shared: InterviewPrepBank {
        CourseLibrary.shared.packages.compactMap(\.interview).first ?? empty
    }
    #endif
    static let empty = Self(schemaVersion: 1, reviewedOn: "", levels: [], topics: [], questions: [], demonstrations: [])

    func filtered(topic: String, level: Int, search: String) -> [InterviewPrepQuestion] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return questions.filter {
            (topic.isEmpty || $0.topic == topic) && (level == 0 || $0.level == level)
                && (query.isEmpty || [$0.title, $0.prompt, $0.topic, $0.answerPoints.joined(separator: " ")]
                    .joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
    }
}
struct InterviewPrepTopic: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let route: String
}
struct InterviewPrepQuestion: Codable, Identifiable, Sendable {
    let id: String
    let topic: String
    let level: Int
    let title: String
    let prompt: String
    let answerPoints: [String]
    let trap: String
    let exercise: String
    let solution: String
    let followUp: String
    let references: [String]
    let code: String
    let complexity: String
}
struct AlgorithmDemonstration: Codable, Identifiable, Sendable {
    let id: String
    let cases: [AlgorithmCase]
}
struct AlgorithmCase: Codable, Sendable {
    let name: String
    let input: String
    let result: String
    let steps: [AlgorithmStep]
}
struct AlgorithmStep: Codable, Sendable {
    let title: String
    let note: String
    let rows: [AlgorithmRow]
}
struct AlgorithmRow: Codable, Sendable {
    let label: String
    let values: [String]
    let active: [Int]
}
